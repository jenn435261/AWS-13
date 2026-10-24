package org

import (
	"crypto/ed25519"
	"encoding/hex"
	"testing"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/events"
	"google.golang.org/protobuf/proto"
)

func TestIsVerifiedOrgTrueOnlyForConfigured(t *testing.T) {
	trustedPub, _, _ := ed25519.GenerateKey(nil)
	otherPub, _, _ := ed25519.GenerateKey(nil)

	trustedHex := hex.EncodeToString(trustedPub)
	to := NewTrustedOrgs([]string{" " + trustedHex + " ", ""})

	if !to.IsVerifiedOrg(trustedHex) {
		t.Fatalf("configured trusted org should be verified")
	}
	// Case-insensitive on hex.
	if !to.IsVerifiedOrg(upper(trustedHex)) {
		t.Fatalf("hex comparison should be case-insensitive")
	}
	if to.IsVerifiedOrg(hex.EncodeToString(otherPub)) {
		t.Fatalf("unconfigured key must NOT be verified")
	}
	if to.IsVerifiedOrgKey(otherPub) {
		t.Fatalf("unconfigured key (bytes) must NOT be verified")
	}
	if to.Len() != 1 {
		t.Fatalf("expected exactly 1 trusted org, got %d", to.Len())
	}
}

func TestParseTrustedOrgs(t *testing.T) {
	a, _, _ := ed25519.GenerateKey(nil)
	b, _, _ := ed25519.GenerateKey(nil)
	csv := hex.EncodeToString(a) + "," + hex.EncodeToString(b)
	to := ParseTrustedOrgs(csv)
	if to.Len() != 2 {
		t.Fatalf("want 2 trusted orgs, got %d", to.Len())
	}
	if !to.IsVerifiedOrgKey(a) || !to.IsVerifiedOrgKey(b) {
		t.Fatalf("both parsed orgs should be verified")
	}
}

func TestValidateAlert(t *testing.T) {
	trustedPub, trustedPriv, _ := ed25519.GenerateKey(nil)
	_, untrustedPriv, _ := ed25519.GenerateKey(nil)

	to := NewTrustedOrgs([]string{hex.EncodeToString(trustedPub)})

	alertBody, err := proto.Marshal(&resiliencev1.EmergencyAlertBody{
		AlertId: "a1",
		Title:   "Evacuate",
	})
	if err != nil {
		t.Fatalf("marshal alert: %v", err)
	}

	// Trusted org signs a valid alert -> accepted.
	good, err := events.BuildSignedEvent(&resiliencev1.EventHeader{
		Type:          resiliencev1.EventType_EVENT_TYPE_EMERGENCY_ALERT,
		Lamport:       1,
		CreatedAtMs:   1_700_000_000_000,
		SchemaVersion: 1,
	}, alertBody, trustedPriv)
	if err != nil {
		t.Fatalf("build good alert: %v", err)
	}
	if !to.ValidateAlert(good) {
		t.Fatalf("valid alert from trusted org should validate")
	}

	// Untrusted org signs a valid alert -> rejected (not authoritative).
	bad, err := events.BuildSignedEvent(&resiliencev1.EventHeader{
		Type:          resiliencev1.EventType_EVENT_TYPE_EMERGENCY_ALERT,
		Lamport:       1,
		CreatedAtMs:   1_700_000_000_000,
		SchemaVersion: 1,
	}, alertBody, untrustedPriv)
	if err != nil {
		t.Fatalf("build bad alert: %v", err)
	}
	if to.ValidateAlert(bad) {
		t.Fatalf("alert from untrusted key must NOT validate")
	}

	// A non-alert event type from a trusted org -> rejected.
	notAlert, err := events.BuildSignedEvent(&resiliencev1.EventHeader{
		Type:          resiliencev1.EventType_EVENT_TYPE_HELP_REQUESTED,
		Lamport:       2,
		CreatedAtMs:   1_700_000_000_000,
		SchemaVersion: 1,
	}, []byte("x"), trustedPriv)
	if err != nil {
		t.Fatalf("build non-alert: %v", err)
	}
	if to.ValidateAlert(notAlert) {
		t.Fatalf("non-alert event must NOT validate as an alert")
	}

	// A tampered alert (bad signature/content hash) -> rejected.
	tampered, _ := events.BuildSignedEvent(&resiliencev1.EventHeader{
		Type:          resiliencev1.EventType_EVENT_TYPE_EMERGENCY_ALERT,
		Lamport:       3,
		CreatedAtMs:   1_700_000_000_000,
		SchemaVersion: 1,
	}, alertBody, trustedPriv)
	tampered.Body = []byte("tampered")
	if to.ValidateAlert(tampered) {
		t.Fatalf("tampered alert must NOT validate")
	}
}

func upper(s string) string {
	out := []byte(s)
	for i := range out {
		if out[i] >= 'a' && out[i] <= 'f' {
			out[i] -= 32
		}
	}
	return string(out)
}
