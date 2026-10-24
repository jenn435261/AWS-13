package feeds

import (
	"crypto/ed25519"
	"os"
	"path/filepath"
	"testing"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/events"
	"google.golang.org/protobuf/proto"
)

// readFixture loads a canned feed document from testdata. Feed tests NEVER make
// a live network call: every byte comes from a checked-in fixture so the
// mapping is deterministic and runs offline.
func readFixture(t *testing.T, name string) []byte {
	t.Helper()
	b, err := os.ReadFile(filepath.Join("testdata", name))
	if err != nil {
		t.Fatalf("read fixture %s: %v", name, err)
	}
	return b
}

func findByNative(recs []AlertRecord, nativeID string) (AlertRecord, bool) {
	for _, r := range recs {
		if r.NativeID == nativeID {
			return r, true
		}
	}
	return AlertRecord{}, false
}

func TestNWSParse(t *testing.T) {
	recs, err := NewNWS().Parse(readFixture(t, "nws.json"))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	// The geometry-less feature must be skipped (never fabricate a point).
	if len(recs) != 2 {
		t.Fatalf("got %d records, want 2 (geometry-less skipped)", len(recs))
	}
	flood, ok := findByNative(recs, "urn:oid:2.49.0.1.840.0.abc123.001.1")
	if !ok {
		t.Fatal("flood warning missing")
	}
	if flood.Source != SourceNWS {
		t.Fatalf("source = %q, want nws", flood.Source)
	}
	if flood.Title != "Flood Warning" {
		t.Fatalf("title = %q", flood.Title)
	}
	if flood.Severity != SeveritySevere {
		t.Fatalf("severity = %q, want severe", flood.Severity)
	}
	// Polygon centroid of the 5-vertex ring: lon mean -122.46, lat mean 37.78.
	if flood.Lat < 37.7 || flood.Lat > 37.9 || flood.Lon < -122.6 || flood.Lon > -122.2 {
		t.Fatalf("centroid out of range: (%f, %f)", flood.Lat, flood.Lon)
	}
	if flood.ExpiresMs == 0 {
		t.Fatal("expires not parsed")
	}
	heat, ok := findByNative(recs, "urn:oid:2.49.0.1.840.0.abc123.002.1")
	if !ok {
		t.Fatal("heat warning missing")
	}
	if heat.Severity != SeverityExtreme {
		t.Fatalf("heat severity = %q, want extreme", heat.Severity)
	}
	if heat.Lat != 34.05 || heat.Lon != -118.24 {
		t.Fatalf("point geometry: (%f, %f)", heat.Lat, heat.Lon)
	}
}

func TestUSGSParse(t *testing.T) {
	recs, err := NewUSGS().Parse(readFixture(t, "usgs.json"))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(recs) != 2 {
		t.Fatalf("got %d, want 2 (empty id skipped)", len(recs))
	}
	q, ok := findByNative(recs, "us7000efgh")
	if !ok {
		t.Fatal("honshu quake missing")
	}
	if q.Severity != SeverityExtreme {
		t.Fatalf("severity = %q, want extreme (red pager)", q.Severity)
	}
	if q.Lat != 38.30 || q.Lon != 142.37 {
		t.Fatalf("point: (%f, %f)", q.Lat, q.Lon)
	}
	if q.OnsetMs != 1769100000000 {
		t.Fatalf("onset = %d", q.OnsetMs)
	}
}

func TestWildfireParse(t *testing.T) {
	recs, err := NewWildfire().Parse(readFixture(t, "wildfire.json"))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(recs) != 2 {
		t.Fatalf("got %d, want 2 (no-id skipped)", len(recs))
	}
	donner, ok := findByNative(recs, "A1B2C3D4-0001")
	if !ok {
		t.Fatal("donner fire missing")
	}
	if donner.Severity != SeverityExtreme {
		t.Fatalf("severity = %q, want extreme (big, low containment)", donner.Severity)
	}
	wasatch, ok := findByNative(recs, "2026-UTUWF-000456")
	if !ok {
		t.Fatal("wasatch fire missing (should use UniqueFireIdentifier)")
	}
	if wasatch.Severity != SeveritySevere {
		t.Fatalf("severity = %q, want severe", wasatch.Severity)
	}
}

func TestFEMAParse(t *testing.T) {
	recs, err := NewFEMA().Parse(readFixture(t, "fema.json"))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(recs) != 2 {
		t.Fatalf("got %d, want 2 (unknown state skipped)", len(recs))
	}
	ca, ok := findByNative(recs, "DR-4800-CA")
	if !ok {
		t.Fatal("CA declaration missing")
	}
	if ca.Severity != SeveritySevere {
		t.Fatalf("severity = %q, want severe (DR)", ca.Severity)
	}
	// CA centroid from the table.
	if ca.Lat < 36 || ca.Lat > 37 || ca.Lon > -119 || ca.Lon < -120 {
		t.Fatalf("CA centroid wrong: (%f, %f)", ca.Lat, ca.Lon)
	}
	if _, ok := findByNative(recs, "DR-9999-ZZ"); ok {
		t.Fatal("unknown-state declaration must be skipped (no fabricated point)")
	}
}

func TestGDACSParse(t *testing.T) {
	recs, err := NewGDACS().Parse(readFixture(t, "gdacs.json"))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(recs) != 2 {
		t.Fatalf("got %d, want 2 (missing id/type skipped)", len(recs))
	}
	tc, ok := findByNative(recs, "TC-1001234")
	if !ok {
		t.Fatal("tropical cyclone missing")
	}
	if tc.Severity != SeverityExtreme {
		t.Fatalf("severity = %q, want extreme (red)", tc.Severity)
	}
	if tc.Detail == "" || containsHTML(tc.Detail) {
		t.Fatalf("detail should be stripped of HTML: %q", tc.Detail)
	}
}

func containsHTML(s string) bool {
	for i := 0; i+1 < len(s); i++ {
		if s[i] == '<' {
			return true
		}
	}
	return false
}

// TestSignRecordVerifies asserts every produced event verifies with the shared
// events.VerifyEvent (the same fail-closed check the store runs) and carries
// the official_feed marker + namespaced id.
func TestSignRecordVerifies(t *testing.T) {
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("key: %v", err)
	}
	in := NewIngestor(priv, 3600_000)

	all := []AlertRecord{}
	for _, f := range []Feed{NewNWS(), NewUSGS(), NewWildfire(), NewFEMA(), NewGDACS()} {
		recs, perr := f.Parse(readFixture(t, string(f.Source())+".json"))
		if perr != nil {
			t.Fatalf("%s parse: %v", f.Source(), perr)
		}
		all = append(all, recs...)
	}
	if len(all) == 0 {
		t.Fatal("no records parsed")
	}

	const nowMs = 1769300000000
	evs, err := in.SignAll(all, 0, nowMs)
	if err != nil {
		t.Fatalf("sign all: %v", err)
	}
	if len(evs) != len(all) {
		t.Fatalf("signed %d events for %d records", len(evs), len(all))
	}
	seenLamport := map[uint64]bool{}
	for _, ev := range evs {
		if ok, reason := events.VerifyEvent(ev); !ok {
			t.Fatalf("event failed verification: %s", reason)
		}
		if ev.GetHeader().GetType() != resiliencev1.EventType_EVENT_TYPE_EMERGENCY_ALERT {
			t.Fatalf("wrong type %v", ev.GetHeader().GetType())
		}
		lam := ev.GetHeader().GetLamport()
		if seenLamport[lam] {
			t.Fatalf("duplicate lamport %d", lam)
		}
		seenLamport[lam] = true

		var body resiliencev1.EmergencyAlertBody
		if uerr := proto.Unmarshal(ev.GetBody(), &body); uerr != nil {
			t.Fatalf("unmarshal body: %v", uerr)
		}
		if !IsFeed(body.GetDetail()) {
			t.Fatalf("detail missing official_feed marker: %q", body.GetDetail())
		}
		src, ok := SourceOf(body.GetDetail())
		if !ok {
			t.Fatalf("SourceOf failed on %q", body.GetDetail())
		}
		wantPrefix := "feed:" + string(src) + ":"
		if got := body.GetAlertId(); len(got) <= len(wantPrefix) || got[:len(wantPrefix)] != wantPrefix {
			t.Fatalf("alert_id %q missing prefix %q", got, wantPrefix)
		}
		if body.GetExpiresMs() == 0 {
			t.Fatal("expires_ms must be set (explicit or default TTL)")
		}
	}
}

// TestSignDeterministic asserts that signing the same records with the same key
// and clock produces byte-identical events (so re-ingest dedups by content
// hash in the store).
func TestSignDeterministic(t *testing.T) {
	seed := make([]byte, ed25519.SeedSize)
	for i := range seed {
		seed[i] = byte(i)
	}
	priv := ed25519.NewKeyFromSeed(seed)
	in := NewIngestor(priv, 3600_000)
	recs, _ := NewUSGS().Parse(readFixture(t, "usgs.json"))

	const nowMs = 1769300000000
	a, err := in.SignAll(recs, 0, nowMs)
	if err != nil {
		t.Fatalf("sign a: %v", err)
	}
	b, err := in.SignAll(recs, 0, nowMs)
	if err != nil {
		t.Fatalf("sign b: %v", err)
	}
	if len(a) != len(b) {
		t.Fatalf("len mismatch %d vs %d", len(a), len(b))
	}
	for i := range a {
		ba, _ := proto.Marshal(a[i])
		bb, _ := proto.Marshal(b[i])
		if string(ba) != string(bb) {
			t.Fatalf("event %d not byte-identical across runs", i)
		}
	}
}

func TestSkipRecordWithoutNativeID(t *testing.T) {
	_, priv, _ := ed25519.GenerateKey(nil)
	in := NewIngestor(priv, 3600_000)
	evs, err := in.SignAll([]AlertRecord{
		{Source: SourceNWS, NativeID: "", Title: "no id"},
		{Source: SourceNWS, NativeID: "ok", Title: "good", Lat: 1, Lon: 2},
	}, 0, 1)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	if len(evs) != 1 {
		t.Fatalf("expected 1 event (id-less skipped), got %d", len(evs))
	}
}
