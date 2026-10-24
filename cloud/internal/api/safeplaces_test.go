package api

import (
	"context"
	"crypto/ed25519"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/events"
	"github.com/resilience-network/aws13/cloud/internal/org"
	"github.com/resilience-network/aws13/cloud/internal/store"
	"google.golang.org/protobuf/proto"
)

// signResource builds a signed RESOURCE_CREATED event with a location.
func signResource(t *testing.T, priv ed25519.PrivateKey, lamport uint64, title string, cat resiliencev1.ResourceCategory, shelter bool, lat, lon float64, prov resiliencev1.ProvenanceKind) *resiliencev1.SignedEvent {
	t.Helper()
	body := &resiliencev1.ResourceBody{
		ResourceId: title,
		Category:   cat,
		Title:      title,
		Notes:      "notes for " + title,
		IsShelter:  shelter,
		Provenance: prov,
		Location:   &resiliencev1.GeoPoint{ApproxLat: lat, ApproxLon: lon},
	}
	bb, _ := proto.Marshal(body)
	h := &resiliencev1.EventHeader{
		Type:        resiliencev1.EventType_EVENT_TYPE_RESOURCE_CREATED,
		Lamport:     lamport,
		CreatedAtMs: 1_700_000_000_000,
	}
	ev, err := events.BuildSignedEvent(h, bb, priv)
	if err != nil {
		t.Fatalf("build resource: %v", err)
	}
	return ev
}

func TestSafePlacesRankingAndSources(t *testing.T) {
	// A verified-org provider and a community provider, plus a store with both.
	_, verifiedPriv, _ := ed25519.GenerateKey(nil)
	_, communityPriv, _ := ed25519.GenerateKey(nil)
	verifiedPub := verifiedPriv.Public().(ed25519.PublicKey)

	st := store.NewMemStore()
	evs := []*resiliencev1.SignedEvent{
		// Verified hospital near the query point.
		signResource(t, verifiedPriv, 1, "County Hospital",
			resiliencev1.ResourceCategory_RESOURCE_CATEGORY_MEDICAL_HELP, false, 37.77, -122.42,
			resiliencev1.ProvenanceKind_PROVENANCE_KIND_VERIFIED_ORG),
		// Community water supply further away.
		signResource(t, communityPriv, 1, "Water point",
			resiliencev1.ResourceCategory_RESOURCE_CATEGORY_WATER, false, 37.70, -122.50,
			resiliencev1.ProvenanceKind_PROVENANCE_KIND_COMMUNITY),
	}
	applied, rejected, err := st.Push(context.Background(), evs)
	if err != nil || len(rejected) != 0 || len(applied) != 2 {
		t.Fatalf("seed: applied=%d rejected=%d err=%v", len(applied), len(rejected), err)
	}

	// Trust the verified org so its place is tagged verified.
	trusted := org.NewTrustedOrgs([]string{hexLower(verifiedPub)})
	srv := httptest.NewServer(NewServer(st, WithTrustedOrgs(trusted)).Handler())
	defer srv.Close()

	resp, err := http.Get(srv.URL + "/v1/safe-places?lat=37.77&lon=-122.42&hazard=flood")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	var out safePlacesResponse
	if derr := json.NewDecoder(resp.Body).Decode(&out); derr != nil {
		t.Fatalf("decode: %v", derr)
	}
	if len(out.Places) != 2 {
		t.Fatalf("got %d places, want 2: %+v", len(out.Places), out.Places)
	}
	// Verified first.
	if !out.Places[0].Verified || out.Places[0].Source != "verified_org" {
		t.Fatalf("verified place must rank first: %+v", out.Places[0])
	}
	if out.Places[1].Source != "community" {
		t.Fatalf("second place should be community: %+v", out.Places[1])
	}
	// Every place must cite a backing event id (proof of non-fabrication) and
	// an age.
	for _, p := range out.Places {
		if p.EventIDHex == "" {
			t.Fatalf("place missing backing event id: %+v", p)
		}
		if p.AgeMs < 0 {
			t.Fatalf("place negative age: %+v", p)
		}
	}
	// No online assistant configured => the summary must be the rules fallback
	// and degraded must be honestly true.
	if !out.Degraded {
		t.Fatal("degraded must be true when no online assistant is configured")
	}
	if out.Summary == "" {
		t.Fatal("summary should be non-empty (rules fallback)")
	}
}

// TestSafePlacesNoFabrication asserts an empty store yields no places (never
// invents one) and still returns an honest degraded summary.
func TestSafePlacesNoFabrication(t *testing.T) {
	srv := httptest.NewServer(NewServer(store.NewMemStore()).Handler())
	defer srv.Close()
	resp, err := http.Get(srv.URL + "/v1/safe-places?lat=0&lon=0&hazard=earthquake")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	var out safePlacesResponse
	_ = json.NewDecoder(resp.Body).Decode(&out)
	if len(out.Places) != 0 {
		t.Fatalf("empty store must return 0 places, got %d", len(out.Places))
	}
	if !out.Degraded {
		t.Fatal("degraded must be true with rules fallback")
	}
}
