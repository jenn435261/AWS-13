package syncserver

import (
	"bytes"
	"crypto/ed25519"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	resiliencev1 "github.com/resilience-network/aws13/node/gen/resilience/v1"
	"github.com/resilience-network/aws13/node/internal/cache"
	"github.com/resilience-network/aws13/node/internal/events"
	"github.com/resilience-network/aws13/node/internal/webapp"
	"google.golang.org/protobuf/proto"
)

func newKey(t *testing.T) ed25519.PrivateKey {
	t.Helper()
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("key: %v", err)
	}
	return priv
}

func resourceEvent(t *testing.T, priv ed25519.PrivateKey, lamport uint64, title string) *resiliencev1.SignedEvent {
	t.Helper()
	body, err := proto.Marshal(&resiliencev1.ResourceBody{
		Title:        title,
		Category:     resiliencev1.ResourceCategory_RESOURCE_CATEGORY_WATER,
		Amount:       resiliencev1.AmountBand_AMOUNT_BAND_SOME,
		Availability: resiliencev1.Availability_AVAILABILITY_NOW,
	})
	if err != nil {
		t.Fatalf("marshal body: %v", err)
	}
	h := &resiliencev1.EventHeader{
		Type:        resiliencev1.EventType_EVENT_TYPE_RESOURCE_CREATED,
		Lamport:     lamport,
		CreatedAtMs: 1_700_000_000_000 + int64(lamport),
	}
	ev, err := events.BuildSignedEvent(h, body, priv)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	return ev
}

func newTestServer(t *testing.T) (*httptest.Server, *cache.Cache) {
	t.Helper()
	c := cache.New()
	s := New(c)
	mux := http.NewServeMux()
	s.Register(mux)
	mux.Handle("/", webapp.Handler())
	ts := httptest.NewServer(mux)
	t.Cleanup(ts.Close)
	return ts, c
}

func pushProto(t *testing.T, base string, evs ...*resiliencev1.SignedEvent) *resiliencev1.Ack {
	t.Helper()
	req := &resiliencev1.PushEventsRequest{Events: evs}
	body, _ := proto.Marshal(req)
	resp, err := http.Post(base+"/node/v1/push", "application/x-protobuf", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("push: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("push status = %d", resp.StatusCode)
	}
	out, _ := io.ReadAll(resp.Body)
	pr := &resiliencev1.PushEventsResponse{}
	if err := proto.Unmarshal(out, pr); err != nil {
		t.Fatalf("unmarshal push resp: %v", err)
	}
	return pr.GetAck()
}

func pullProto(t *testing.T, base string, from map[string]uint64) []*resiliencev1.SignedEvent {
	t.Helper()
	req := &resiliencev1.PullEventsRequest{}
	for authorHex, l := range from {
		req.From = append(req.From, &resiliencev1.PullEventsRequest_AuthorFrom{
			AuthorPubkey: mustHex(t, authorHex),
			FromLamport:  l,
		})
	}
	body, _ := proto.Marshal(req)
	resp, err := http.Post(base+"/node/v1/pull", "application/x-protobuf", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("pull: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("pull status = %d", resp.StatusCode)
	}
	out, _ := io.ReadAll(resp.Body)
	pr := &resiliencev1.PullEventsResponse{}
	if err := proto.Unmarshal(out, pr); err != nil {
		t.Fatalf("unmarshal pull resp: %v", err)
	}
	return pr.GetBatch().GetEvents()
}

func mustHex(t *testing.T, s string) []byte {
	t.Helper()
	b, err := hex.DecodeString(s)
	if err != nil {
		t.Fatalf("hex: %v", err)
	}
	return b
}

func TestPushValidBatchApplied(t *testing.T) {
	ts, c := newTestServer(t)
	priv := newKey(t)
	ev1 := resourceEvent(t, priv, 1, "Water @ Library")
	ev2 := resourceEvent(t, priv, 2, "Blankets @ Gym")

	ack := pushProto(t, ts.URL, ev1, ev2)
	if len(ack.GetApplied()) != 2 {
		t.Fatalf("applied = %d, want 2", len(ack.GetApplied()))
	}
	if len(ack.GetRejected()) != 0 {
		t.Fatalf("rejected = %d, want 0", len(ack.GetRejected()))
	}
	if c.Len() != 2 {
		t.Fatalf("cache len = %d, want 2", c.Len())
	}
}

func TestPushTamperedRejectedNotStored(t *testing.T) {
	ts, c := newTestServer(t)
	priv := newKey(t)
	ev := resourceEvent(t, priv, 1, "Good")
	ev.Body = []byte("tampered")

	ack := pushProto(t, ts.URL, ev)
	if len(ack.GetApplied()) != 0 {
		t.Fatalf("applied = %d, want 0", len(ack.GetApplied()))
	}
	if len(ack.GetRejected()) != 1 {
		t.Fatalf("rejected = %d, want 1", len(ack.GetRejected()))
	}
	if c.Len() != 0 {
		t.Fatalf("tampered event must not be stored; len = %d", c.Len())
	}
}

func TestHaveDigest(t *testing.T) {
	ts, _ := newTestServer(t)
	priv := newKey(t)
	pushProto(t, ts.URL, resourceEvent(t, priv, 1, "a"), resourceEvent(t, priv, 5, "b"))

	resp, err := http.Get(ts.URL + "/node/v1/have")
	if err != nil {
		t.Fatalf("have: %v", err)
	}
	defer resp.Body.Close()
	var hr haveResponse
	if err := json.NewDecoder(resp.Body).Decode(&hr); err != nil {
		t.Fatalf("decode have: %v", err)
	}
	if len(hr.Authors) != 1 {
		t.Fatalf("authors = %d, want 1", len(hr.Authors))
	}
	if hr.Authors[0].HighWater != 5 {
		t.Fatalf("high water = %d, want 5", hr.Authors[0].HighWater)
	}
}

func TestPullOnlyMissing(t *testing.T) {
	ts, _ := newTestServer(t)
	priv := newKey(t)
	pushProto(t, ts.URL, resourceEvent(t, priv, 1, "a"), resourceEvent(t, priv, 2, "b"), resourceEvent(t, priv, 3, "c"))
	author := cache.AuthorKey(priv.Public().(ed25519.PublicKey))

	got := pullProto(t, ts.URL, map[string]uint64{author: 1})
	if len(got) != 2 {
		t.Fatalf("pull above 1 returned %d events, want 2", len(got))
	}
	for _, ev := range got {
		if ev.GetHeader().GetLamport() <= 1 {
			t.Fatalf("pull returned an event at or below the watermark")
		}
	}
}

// TestTwoPhonesReconcileThroughNode is the headline test: phone A pushes its
// events to the node; phone B, which has nothing, pulls from the node and must
// receive A's events — reconciling two phones purely through the local node,
// with no cloud.
func TestTwoPhonesReconcileThroughNode(t *testing.T) {
	ts, _ := newTestServer(t)

	phoneA := newKey(t)
	phoneB := newKey(t)

	// A publishes two resources and pushes them to the node.
	a1 := resourceEvent(t, phoneA, 1, "A: Water")
	a2 := resourceEvent(t, phoneA, 2, "A: Medicine")
	ack := pushProto(t, ts.URL, a1, a2)
	if len(ack.GetApplied()) != 2 {
		t.Fatalf("A push applied = %d, want 2", len(ack.GetApplied()))
	}

	// B also publishes one of its own and pushes it.
	b1 := resourceEvent(t, phoneB, 1, "B: Shelter")
	pushProto(t, ts.URL, b1)

	// B knows only about its own events (watermark for B=1, nothing for A).
	authorB := cache.AuthorKey(phoneB.Public().(ed25519.PublicKey))
	missing := pullProto(t, ts.URL, map[string]uint64{authorB: 1})

	// B must receive A's two events (and none of its own, since it is caught up).
	if len(missing) != 2 {
		t.Fatalf("B pulled %d events, want 2 (A's events)", len(missing))
	}
	authorA := cache.AuthorKey(phoneA.Public().(ed25519.PublicKey))
	for _, ev := range missing {
		got := cache.AuthorKey(ev.GetHeader().GetAuthorPubkey())
		if got != authorA {
			t.Fatalf("B received an event from %s, expected only A (%s)", got, authorA)
		}
		// Every reconciled event must still verify end-to-end on B's side.
		if ok, reason := events.VerifyEvent(ev); !ok {
			t.Fatalf("reconciled event failed verification on B: %s", reason)
		}
	}
}

func TestWebAppServesHTML(t *testing.T) {
	ts, _ := newTestServer(t)
	resp, err := http.Get(ts.URL + "/")
	if err != nil {
		t.Fatalf("get /: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("GET / status = %d, want 200", resp.StatusCode)
	}
	if ct := resp.Header.Get("Content-Type"); ct == "" || ct[:9] != "text/html" {
		t.Fatalf("GET / content-type = %q, want text/html", ct)
	}
	body, _ := io.ReadAll(resp.Body)
	if !bytes.Contains(body, []byte("Resilience Node")) {
		t.Fatalf("web app HTML missing expected content")
	}
}

func TestStateReturnsJSONFromEvents(t *testing.T) {
	ts, _ := newTestServer(t)
	priv := newKey(t)
	pushProto(t, ts.URL, resourceEvent(t, priv, 1, "Water @ Library"))

	resp, err := http.Get(ts.URL + "/node/v1/state")
	if err != nil {
		t.Fatalf("state: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("state status = %d", resp.StatusCode)
	}
	var st State
	if err := json.NewDecoder(resp.Body).Decode(&st); err != nil {
		t.Fatalf("decode state: %v", err)
	}
	if st.Count != 1 {
		t.Fatalf("state count = %d, want 1", st.Count)
	}
	if len(st.Resources) != 1 || st.Resources[0].Title != "Water @ Library" {
		t.Fatalf("unexpected resources: %+v", st.Resources)
	}
}
