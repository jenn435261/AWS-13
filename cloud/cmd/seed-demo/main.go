// Command seed-demo builds a small, self-consistent set of SIGNED demo events
// for a trusted organisation and (optionally) pushes them to a running cloud
// API. It is the runnable backing for docs/DEMO_ORG_SETUP.md.
//
// What it creates (all as real Ed25519-signed events, verify-before-store
// compatible):
//
//   - an ORG ROOT identity (the demo org's root key);
//   - provider A, certified DIRECTLY by the root (ORG_CERTIFICATE, depth 1);
//   - provider B, certified by provider A (ORG_CERTIFICATE, depth 2 - the
//     maximum the app grants a verified badge, see docs/DECISIONS.md);
//   - two verified supplies (one from each provider);
//   - one emergency alert signed by provider A.
//
// It NEVER fabricates a signature or trust: every event is built with the exact
// EventFactory recipe via events.BuildSignedEvent and re-verified locally with
// events.VerifyEvent before it is printed or pushed. The org root PUBLIC key is
// what an operator installs as a trusted root in the app (Trusted
// organisations) - the script prints it so the demo is reproducible.
//
// Usage:
//
//	go run ./cmd/seed-demo                 # build + verify locally, print a summary (smoke test)
//	go run ./cmd/seed-demo -cloud URL -key APIKEY   # also push to a running cloud API
//	go run ./cmd/seed-demo -seed HEX32     # deterministic org root (else random)
//
// No secrets are committed: private keys only ever live in memory (or in the
// -seed flag the operator supplies). The script prints only PUBLIC keys.
package main

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/events"
	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"
)

func main() {
	cloudURL := flag.String("cloud", "", "cloud base URL to push demo events to (e.g. http://localhost:8187); empty = build+verify only")
	apiKey := flag.String("key", "", "X-Api-Key for the cloud API (if it gates /v1/events)")
	seedHex := flag.String("seed", "", "hex 32-byte seed for the org root key (default: random)")
	flag.Parse()

	if err := run(*cloudURL, *apiKey, *seedHex); err != nil {
		fmt.Fprintln(os.Stderr, "seed-demo:", err)
		os.Exit(1)
	}
}

func run(cloudURL, apiKey, seedHex string) error {
	now := time.Now().UnixMilli()

	// --- identities ---------------------------------------------------------
	orgRoot, err := keyFromSeed(seedHex)
	if err != nil {
		return err
	}
	providerA, _, err := newKey()
	if err != nil {
		return err
	}
	providerB, _, err := newKey()
	if err != nil {
		return err
	}
	orgRootPub := orgRoot.Public().(ed25519.PublicKey)

	// A monotonic Lamport clock per author keeps the DAG honest. Each author
	// starts at 1; we just bump a shared counter per-author here.
	lamport := map[string]uint64{}
	nextLamport := func(pub ed25519.PublicKey) uint64 {
		k := hex.EncodeToString(pub)
		lamport[k]++
		return lamport[k]
	}

	var demo []*resiliencev1.SignedEvent

	// --- org root self-cert (depth 0): the root certifies itself as VERIFIED.
	rootCert, err := buildEvent(orgRoot, nextLamport(orgRootPub), now,
		resiliencev1.EventType_EVENT_TYPE_ORG_CERTIFICATE,
		&resiliencev1.OrgCertificateBody{
			OrgRootPubkey: orgRootPub,
			SubjectPubkey: orgRootPub,
			OrgName:       "Demo Mutual Aid",
			FacilityName:  "Demo Mutual Aid HQ",
			Provenance:    resiliencev1.ProvenanceKind_PROVENANCE_KIND_VERIFIED_ORG,
			ValidFromMs:   now,
			ValidUntilMs:  now + 365*24*3600*1000,
		})
	if err != nil {
		return err
	}
	demo = append(demo, rootCert)

	// --- provider A: certified DIRECTLY by the root (depth 1) ---------------
	certA, err := buildEvent(orgRoot, nextLamport(orgRootPub), now,
		resiliencev1.EventType_EVENT_TYPE_ORG_CERTIFICATE,
		&resiliencev1.OrgCertificateBody{
			OrgRootPubkey: orgRootPub,
			SubjectPubkey: providerA.Public().(ed25519.PublicKey),
			OrgName:       "Demo Mutual Aid",
			FacilityName:  "Eastside Water Point",
			Provenance:    resiliencev1.ProvenanceKind_PROVENANCE_KIND_VERIFIED_ORG,
			ValidFromMs:   now,
			ValidUntilMs:  now + 365*24*3600*1000,
		})
	if err != nil {
		return err
	}
	demo = append(demo, certA)

	// --- provider B: certified by provider A (depth 2, the max) -------------
	certB, err := buildEvent(providerA, nextLamport(providerA.Public().(ed25519.PublicKey)), now,
		resiliencev1.EventType_EVENT_TYPE_ORG_CERTIFICATE,
		&resiliencev1.OrgCertificateBody{
			OrgRootPubkey: orgRootPub,
			SubjectPubkey: providerB.Public().(ed25519.PublicKey),
			OrgName:       "Demo Mutual Aid",
			FacilityName:  "Riverside Clinic",
			Provenance:    resiliencev1.ProvenanceKind_PROVENANCE_KIND_VERIFIED_ORG,
			ValidFromMs:   now,
			ValidUntilMs:  now + 365*24*3600*1000,
		})
	if err != nil {
		return err
	}
	demo = append(demo, certB)

	// --- supply from provider A (verified water) ----------------------------
	supplyA, err := buildEvent(providerA, nextLamport(providerA.Public().(ed25519.PublicKey)), now,
		resiliencev1.EventType_EVENT_TYPE_RESOURCE_CREATED,
		&resiliencev1.ResourceBody{
			ResourceId:   fmt.Sprintf("demo-supply-water-%d", now),
			Category:     resiliencev1.ResourceCategory_RESOURCE_CATEGORY_WATER,
			Title:        "Bottled water",
			Notes:        "Pallet of 1L bottles at the Eastside Water Point.",
			Amount:       resiliencev1.AmountBand_AMOUNT_BAND_PLENTY,
			Availability: resiliencev1.Availability_AVAILABILITY_NOW,
			Location: &resiliencev1.GeoPoint{
				ApproxLat:      37.339,
				ApproxLon:      -121.894,
				LocationSource: resiliencev1.LocationSource_LOCATION_SOURCE_MANUAL,
			},
			Provenance: resiliencev1.ProvenanceKind_PROVENANCE_KIND_VERIFIED_ORG,
		})
	if err != nil {
		return err
	}
	demo = append(demo, supplyA)

	// --- supply from provider B (verified medical) --------------------------
	supplyB, err := buildEvent(providerB, nextLamport(providerB.Public().(ed25519.PublicKey)), now,
		resiliencev1.EventType_EVENT_TYPE_RESOURCE_CREATED,
		&resiliencev1.ResourceBody{
			ResourceId:   fmt.Sprintf("demo-supply-firstaid-%d", now),
			Category:     resiliencev1.ResourceCategory_RESOURCE_CATEGORY_MEDICAL_HELP,
			Title:        "First-aid supplies",
			Notes:        "Bandages, antiseptic, basic meds at the Riverside Clinic.",
			Amount:       resiliencev1.AmountBand_AMOUNT_BAND_SOME,
			Availability: resiliencev1.Availability_AVAILABILITY_TODAY,
			Location: &resiliencev1.GeoPoint{
				ApproxLat:      37.335,
				ApproxLon:      -121.881,
				LocationSource: resiliencev1.LocationSource_LOCATION_SOURCE_MANUAL,
			},
			Provenance: resiliencev1.ProvenanceKind_PROVENANCE_KIND_VERIFIED_ORG,
		})
	if err != nil {
		return err
	}
	demo = append(demo, supplyB)

	// --- emergency alert signed by provider A -------------------------------
	alert, err := buildEvent(providerA, nextLamport(providerA.Public().(ed25519.PublicKey)), now,
		resiliencev1.EventType_EVENT_TYPE_EMERGENCY_ALERT,
		&resiliencev1.EmergencyAlertBody{
			AlertId:  fmt.Sprintf("demo-alert-%d", now),
			Title:    "Boil-water notice - Eastside",
			Detail:   "Tap water in the Eastside area is unsafe. Boil before drinking or use the Water Point.",
			Priority: resiliencev1.Priority_PRIORITY_HIGH,
			Area: &resiliencev1.GeoPoint{
				ApproxLat: 37.339,
				ApproxLon: -121.894,
			},
			ExpiresMs: now + 12*3600*1000,
		})
	if err != nil {
		return err
	}
	demo = append(demo, alert)

	// --- verify everything locally (smoke) ----------------------------------
	for i, ev := range demo {
		ok, verr := events.VerifyEvent(ev)
		if !ok {
			return fmt.Errorf("event %d (%s) failed local verify: %v", i, ev.GetHeader().GetType(), verr)
		}
	}

	fmt.Println("demo org seed - built and locally verified", len(demo), "signed events")
	fmt.Println("  org root PUBLIC key (install as a trusted org in the app):")
	fmt.Println("    ", hex.EncodeToString(orgRootPub))
	fmt.Println("  provider A (depth 1, verified):", hex.EncodeToString(providerA.Public().(ed25519.PublicKey)))
	fmt.Println("  provider B (depth 2, verified):", hex.EncodeToString(providerB.Public().(ed25519.PublicKey)))
	for _, ev := range demo {
		fmt.Printf("  - %-32s id=%s\n", ev.GetHeader().GetType(), hex.EncodeToString(ev.GetHeader().GetEventId())[:16])
	}

	if cloudURL == "" {
		fmt.Println("no -cloud URL given: build+verify only (smoke OK). Pass -cloud http://localhost:8187 to push.")
		return nil
	}

	if err := push(cloudURL, apiKey, demo); err != nil {
		return err
	}
	fmt.Println("pushed", len(demo), "events to", cloudURL)
	return nil
}

// buildEvent fills a header and builds a signed, content-addressed event.
func buildEvent(priv ed25519.PrivateKey, lamport uint64, nowMs int64, t resiliencev1.EventType, body proto.Message) (*resiliencev1.SignedEvent, error) {
	raw, err := proto.Marshal(body)
	if err != nil {
		return nil, err
	}
	h := &resiliencev1.EventHeader{
		Type:          t,
		Lamport:       lamport,
		CreatedAtMs:   nowMs,
		SchemaVersion: 1,
	}
	return events.BuildSignedEvent(h, raw, priv)
}

// push JSON-encodes a PushEventsRequest and POSTs it to /v1/events.
func push(baseURL, apiKey string, evs []*resiliencev1.SignedEvent) error {
	reqMsg := &resiliencev1.PushEventsRequest{Events: evs}
	payload, err := protojson.Marshal(reqMsg)
	if err != nil {
		return err
	}
	httpReq, err := http.NewRequestWithContext(context.Background(), http.MethodPost,
		baseURL+"/v1/events", bytes.NewReader(payload))
	if err != nil {
		return err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Accept", "application/json")
	if apiKey != "" {
		httpReq.Header.Set("X-Api-Key", apiKey)
	}
	resp, err := http.DefaultClient.Do(httpReq)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("cloud push returned %d: %s", resp.StatusCode, string(respBody))
	}
	return nil
}

func newKey() (ed25519.PrivateKey, ed25519.PublicKey, error) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	return priv, pub, err
}

// keyFromSeed derives the org root key from a hex 32-byte seed, or generates a
// random one when seedHex is empty.
func keyFromSeed(seedHex string) (ed25519.PrivateKey, error) {
	if seedHex == "" {
		priv, _, err := newKey()
		return priv, err
	}
	seed, err := hex.DecodeString(seedHex)
	if err != nil {
		return nil, fmt.Errorf("decode -seed hex: %w", err)
	}
	if len(seed) != ed25519.SeedSize {
		return nil, fmt.Errorf("-seed must be %d bytes (hex), got %d", ed25519.SeedSize, len(seed))
	}
	return ed25519.NewKeyFromSeed(seed), nil
}
