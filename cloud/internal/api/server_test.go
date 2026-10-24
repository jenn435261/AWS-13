package api

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/events"
	"github.com/resilience-network/aws13/cloud/internal/store"
	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"
)

func newTestEvent(t *testing.T, lamport uint64, body string) (*resiliencev1.SignedEvent, ed25519.PublicKey) {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("keygen: %v", err)
	}
	h := &resiliencev1.EventHeader{
		Type:          resiliencev1.EventType_EVENT_TYPE_RESOURCE_CREATED,
		Lamport:       lamport,
		CreatedAtMs:   1_700_000_000_000,
		SchemaVersion: 1,
	}
	ev, err := events.BuildSignedEvent(h, []byte(body), priv)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	return ev, pub
}

func TestServerHealthz(t *testing.T) {
	srv := httptest.NewServer(NewServer(store.NewMemStore()).Handler())
	defer srv.Close()

	resp, err := http.Get(srv.URL + "/healthz")
	if err != nil {
		t.Fatalf("get healthz: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("healthz status = %d, want 200", resp.StatusCode)
	}
}

func TestServerReadyz(t *testing.T) {
	srv := httptest.NewServer(NewServer(store.NewMemStore()).Handler())
	defer srv.Close()

	resp, err := http.Get(srv.URL + "/readyz")
	if err != nil {
		t.Fatalf("get readyz: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("readyz status = %d, want 200", resp.StatusCode)
	}
}

func postJSON(t *testing.T, url string, msg proto.Message) *http.Response {
	t.Helper()
	raw, err := protojson.Marshal(msg)
	if err != nil {
		t.Fatalf("marshal json: %v", err)
	}
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(raw))
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	return resp
}

func TestServerPushVerifiesAndPulls(t *testing.T) {
	st := store.NewMemStore()
	srv := httptest.NewServer(NewServer(st).Handler())
	defer srv.Close()

	valid, pub := newTestEvent(t, 1, "valid")

	tampered, _ := newTestEvent(t, 2, "orig")
	tampered.Body = []byte("tampered")

	pushReq := &resiliencev1.PushEventsRequest{
		Events: []*resiliencev1.SignedEvent{valid, tampered},
	}

	resp := postJSON(t, srv.URL+"/v1/events", pushReq)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("push status = %d, want 200", resp.StatusCode)
	}
	bodyBytes, _ := io.ReadAll(resp.Body)
	pushResp := &resiliencev1.PushEventsResponse{}
	if err := protojson.Unmarshal(bodyBytes, pushResp); err != nil {
		t.Fatalf("unmarshal push resp: %v", err)
	}

	if len(pushResp.GetAck().GetApplied()) != 1 {
		t.Fatalf("expected 1 applied, got %d", len(pushResp.GetAck().GetApplied()))
	}
	if !bytes.Equal(pushResp.GetAck().GetApplied()[0], valid.GetHeader().GetEventId()) {
		t.Fatalf("applied id does not match the valid event")
	}
	if len(pushResp.GetAck().GetRejected()) != 1 {
		t.Fatalf("expected 1 rejected, got %d", len(pushResp.GetAck().GetRejected()))
	}

	// Pull should return exactly the valid event.
	pullReq := &resiliencev1.PullEventsRequest{
		From: []*resiliencev1.PullEventsRequest_AuthorFrom{
			{AuthorPubkey: pub, FromLamport: 0},
		},
	}
	presp := postJSON(t, srv.URL+"/v1/events/pull", pullReq)
	defer presp.Body.Close()
	if presp.StatusCode != http.StatusOK {
		t.Fatalf("pull status = %d, want 200", presp.StatusCode)
	}
	pbody, _ := io.ReadAll(presp.Body)
	pullResp := &resiliencev1.PullEventsResponse{}
	if err := protojson.Unmarshal(pbody, pullResp); err != nil {
		t.Fatalf("unmarshal pull resp: %v", err)
	}
	evs := pullResp.GetBatch().GetEvents()
	if len(evs) != 1 {
		t.Fatalf("expected 1 pulled event, got %d", len(evs))
	}
	if !bytes.Equal(evs[0].GetHeader().GetEventId(), valid.GetHeader().GetEventId()) {
		t.Fatalf("pulled event id mismatch")
	}

	// Confirm the tampered event was never stored.
	if _, ok, _ := st.Get(context.Background(), tampered.GetHeader().GetEventId()); ok {
		t.Fatalf("tampered event should not be stored")
	}
}

func TestClientGate(t *testing.T) {
	srv := NewServer(store.NewMemStore(), WithClientTokens([]string{"k1"}))
	h := srv.Handler()
	do := func(path string, hdr map[string]string) int {
		req := httptest.NewRequest(http.MethodPost, path, strings.NewReader(`{"text":"water needed"}`))
		req.Header.Set("Content-Type", "application/json")
		for k, v := range hdr {
			req.Header.Set(k, v)
		}
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		return rec.Code
	}
	if c := do("/v1/ai/structure", nil); c != http.StatusUnauthorized {
		t.Fatalf("no key: got %d want 401", c)
	}
	if c := do("/v1/events/pull", map[string]string{"X-Api-Key": "bad"}); c != http.StatusUnauthorized {
		t.Fatalf("bad key: got %d want 401", c)
	}
	if c := do("/v1/ai/structure", map[string]string{"X-Api-Key": "k1"}); c != http.StatusOK {
		t.Fatalf("good key: got %d want 200", c)
	}
	if c := do("/v1/ai/structure", map[string]string{"Authorization": "Bearer k1"}); c != http.StatusOK {
		t.Fatalf("bearer: got %d want 200", c)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("healthz must stay open, got %d", rec.Code)
	}
}

func TestWebServing(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "index.html"), []byte("<html>app</html>"), 0o644); err != nil {
		t.Fatal(err)
	}
	h := NewServer(store.NewMemStore(), WithWebDir(dir), WithClientTokens([]string{"webk"})).Handler()
	get := func(path string) *httptest.ResponseRecorder {
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
		return rec
	}
	if r := get("/"); r.Code != 200 || !strings.Contains(r.Body.String(), "app") {
		t.Fatalf("index: %d %q", r.Code, r.Body.String())
	}
	if r := get("/some/client/route"); r.Code != 200 || !strings.Contains(r.Body.String(), "app") {
		t.Fatalf("spa fallback: %d", r.Code)
	}
	if r := get("/v1/nope"); r.Code != 404 {
		t.Fatalf("/v1 unknown must 404, got %d", r.Code)
	}
	if r := get("/app-config.json"); r.Code != 200 || !strings.Contains(r.Body.String(), `"apiKey":"webk"`) {
		t.Fatalf("config: %d %q", r.Code, r.Body.String())
	}
}
