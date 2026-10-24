package api

import (
	"context"
	"crypto/ed25519"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/feeds"
	"github.com/resilience-network/aws13/cloud/internal/store"
	"google.golang.org/protobuf/encoding/protojson"
)

// feedFixtureStore builds a MemStore seeded with signed official-feed alerts at
// known locations, returning the store, the feed public key, and the signed
// events. NO live network: records are hand-built AlertRecords.
func feedFixtureStore(t *testing.T) (*store.MemStore, ed25519.PublicKey, *feeds.Ingestor) {
	t.Helper()
	seed := make([]byte, ed25519.SeedSize)
	seed[0] = 9
	priv := ed25519.NewKeyFromSeed(seed)
	in := feeds.NewIngestor(priv, 3600_000)

	recs := []feeds.AlertRecord{
		// Near San Francisco.
		{Source: feeds.SourceNWS, NativeID: "sf-flood", Title: "Flood Warning",
			Detail: "River flooding", Severity: feeds.SeveritySevere, Lat: 37.77, Lon: -122.42,
			ExpiresMs: 4102444800000},
		// Near New York (far from SF).
		{Source: feeds.SourceNWS, NativeID: "ny-heat", Title: "Heat Warning",
			Detail: "Excessive heat", Severity: feeds.SeverityExtreme, Lat: 40.71, Lon: -74.00,
			ExpiresMs: 4102444800000},
		// An official-feed open shelter near SF (title mentions shelter).
		{Source: feeds.SourceFEMA, NativeID: "sf-shelter", Title: "Evacuation shelter open",
			Detail: "Red Cross shelter at the community center", Severity: feeds.SeverityModerate,
			Lat: 37.78, Lon: -122.41, ExpiresMs: 4102444800000},
	}
	evs, err := in.SignAll(recs, 0, 1_700_000_000_000)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	st := store.NewMemStore()
	applied, rejected, err := st.Push(context.Background(), evs)
	if err != nil || len(rejected) != 0 || len(applied) != len(evs) {
		t.Fatalf("seed push: applied=%d rejected=%d err=%v", len(applied), len(rejected), err)
	}
	return st, priv.Public().(ed25519.PublicKey), in
}

func TestAlertsRadiusFilter(t *testing.T) {
	st, pub, _ := feedFixtureStore(t)
	srv := httptest.NewServer(NewServer(st, WithFeedPubkey(pub)).Handler())
	defer srv.Close()

	// A 100km radius around SF must include the two SF alerts and exclude NY.
	resp, err := http.Get(srv.URL + "/v1/alerts?lat=37.77&lon=-122.42&radius_km=100")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	var out alertsResponse
	if derr := json.NewDecoder(resp.Body).Decode(&out); derr != nil {
		t.Fatalf("decode: %v", derr)
	}
	if out.FeedPubkey == "" {
		t.Fatal("feed_pubkey must be advertised so clients trust the root")
	}
	if len(out.Alerts) != 2 {
		t.Fatalf("got %d alerts in SF radius, want 2 (NY excluded): %+v", len(out.Alerts), out.Alerts)
	}
	for _, a := range out.Alerts {
		if a.AlertID == "feed:nws:ny-heat" {
			t.Fatal("NY alert leaked into SF radius")
		}
		if a.Source == "" || a.AgeMs < 0 {
			t.Fatalf("alert missing source/age: %+v", a)
		}
	}
	// Nearest-first: the SF flood (at the query point) should rank before the
	// shelter slightly away.
	if out.Alerts[0].DistKm > out.Alerts[1].DistKm {
		t.Fatalf("alerts not sorted nearest-first: %v", out.Alerts)
	}
}

func TestAlertsSinceFilter(t *testing.T) {
	st, pub, _ := feedFixtureStore(t)
	srv := httptest.NewServer(NewServer(st, WithFeedPubkey(pub)).Handler())
	defer srv.Close()

	// since == created_at means strictly-after; all alerts share created_at
	// 1.7e12, so since at that value returns none.
	resp, err := http.Get(srv.URL + "/v1/alerts?since=1700000000000")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	var out alertsResponse
	_ = json.NewDecoder(resp.Body).Decode(&out)
	if len(out.Alerts) != 0 {
		t.Fatalf("since filter returned %d, want 0", len(out.Alerts))
	}
}

func TestAlertsEmptyWhenNoFeedConfigured(t *testing.T) {
	st, _, _ := feedFixtureStore(t)
	// No WithFeedPubkey => honest empty set, no fabrication.
	srv := httptest.NewServer(NewServer(st).Handler())
	defer srv.Close()
	resp, err := http.Get(srv.URL + "/v1/alerts")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	var out alertsResponse
	_ = json.NewDecoder(resp.Body).Decode(&out)
	if len(out.Alerts) != 0 || out.FeedPubkey != "" {
		t.Fatalf("unconfigured feed should return empty: %+v", out)
	}
}

// TestFeedAlertsAppearInPull proves the same feed alerts are returned by the
// ordinary /v1/events/pull so existing sync picks them up.
func TestFeedAlertsAppearInPull(t *testing.T) {
	st, pub, _ := feedFixtureStore(t)
	srv := httptest.NewServer(NewServer(st, WithFeedPubkey(pub)).Handler())
	defer srv.Close()

	// A pull with an empty watermark returns every stored event.
	resp, err := http.Post(srv.URL+"/v1/events/pull", contentTypeJSON, nil)
	if err != nil {
		t.Fatalf("pull: %v", err)
	}
	defer resp.Body.Close()
	var pr resiliencev1.PullEventsResponse
	body, rerr := io.ReadAll(resp.Body)
	if rerr != nil {
		t.Fatalf("read pull: %v", rerr)
	}
	if uerr := protojson.Unmarshal(body, &pr); uerr != nil {
		t.Fatalf("decode pull: %v", uerr)
	}
	var alertCount int
	for _, ev := range pr.GetBatch().GetEvents() {
		if ev.GetHeader().GetType() == resiliencev1.EventType_EVENT_TYPE_EMERGENCY_ALERT {
			alertCount++
		}
	}
	if alertCount != 3 {
		t.Fatalf("pull returned %d alert events, want 3", alertCount)
	}
}
