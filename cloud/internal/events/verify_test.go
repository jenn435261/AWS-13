package events

import (
	"crypto/ed25519"
	"testing"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"google.golang.org/protobuf/proto"
)

func mustKey(t *testing.T) (ed25519.PublicKey, ed25519.PrivateKey) {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("generate key: %v", err)
	}
	return pub, priv
}

func sampleHeader() *resiliencev1.EventHeader {
	return &resiliencev1.EventHeader{
		Type:          resiliencev1.EventType_EVENT_TYPE_RESOURCE_CREATED,
		Lamport:       7,
		PrevEventId:   []byte{0x01, 0x02},
		CreatedAtMs:   1_700_000_000_000,
		SchemaVersion: 1,
		H3Cell:        0x8928308280fffff,
	}
}

func TestBuildAndVerifyRoundTrip(t *testing.T) {
	_, priv := mustKey(t)
	body := []byte("resource-body-bytes")

	ev, err := BuildSignedEvent(sampleHeader(), body, priv)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	if len(ev.GetHeader().GetEventId()) != DigestLen {
		t.Fatalf("event id length = %d, want %d", len(ev.GetHeader().GetEventId()), DigestLen)
	}
	if len(ev.GetSignature()) != ed25519.SignatureSize {
		t.Fatalf("sig length = %d, want %d", len(ev.GetSignature()), ed25519.SignatureSize)
	}

	ok, reason := VerifyEvent(ev)
	if !ok {
		t.Fatalf("expected valid event, got reason: %s", reason)
	}
}

func TestVerifyFailsOnTamperedBody(t *testing.T) {
	_, priv := mustKey(t)
	ev, err := BuildSignedEvent(sampleHeader(), []byte("original"), priv)
	if err != nil {
		t.Fatalf("build: %v", err)
	}

	// Tamper the body without recomputing the id/signature.
	ev.Body = []byte("tampered!")

	ok, reason := VerifyEvent(ev)
	if ok {
		t.Fatalf("expected tampered body to fail verification")
	}
	if reason == "" {
		t.Fatalf("expected a failure reason")
	}
}

func TestVerifyFailsOnTamperedSignature(t *testing.T) {
	_, priv := mustKey(t)
	ev, err := BuildSignedEvent(sampleHeader(), []byte("body"), priv)
	if err != nil {
		t.Fatalf("build: %v", err)
	}

	// Flip a bit in the signature.
	ev.Signature[0] ^= 0xFF

	if ok, _ := VerifyEvent(ev); ok {
		t.Fatalf("expected tampered signature to fail verification")
	}
}

func TestVerifyFailsOnWrongAuthor(t *testing.T) {
	_, priv := mustKey(t)
	ev, err := BuildSignedEvent(sampleHeader(), []byte("body"), priv)
	if err != nil {
		t.Fatalf("build: %v", err)
	}

	// Replace author pubkey with a different valid key. This invalidates the
	// content hash too, but importantly the event is no longer authentic.
	otherPub, _ := mustKey(t)
	ev.Header.AuthorPubkey = otherPub

	if ok, _ := VerifyEvent(ev); ok {
		t.Fatalf("expected wrong author to fail verification")
	}
}

func TestVerifyFailsOnUnspecifiedType(t *testing.T) {
	_, priv := mustKey(t)
	h := sampleHeader()
	h.Type = resiliencev1.EventType_EVENT_TYPE_UNSPECIFIED
	ev, err := BuildSignedEvent(h, []byte("body"), priv)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	if ok, reason := VerifyEvent(ev); ok {
		t.Fatalf("expected unspecified type to fail; reason=%q", reason)
	}
}

func TestCanonicalHeaderDeterministic(t *testing.T) {
	h := sampleHeader()
	h.EventId = make([]byte, DigestLen)

	a, err := canonicalHeaderBytes(h, true)
	if err != nil {
		t.Fatalf("marshal a: %v", err)
	}
	b, err := canonicalHeaderBytes(h, true)
	if err != nil {
		t.Fatalf("marshal b: %v", err)
	}
	if string(a) != string(b) {
		t.Fatalf("canonical encoding not deterministic")
	}

	// includeId=false must clear the id, producing different (shorter) bytes.
	noID, err := canonicalHeaderBytes(h, false)
	if err != nil {
		t.Fatalf("marshal noID: %v", err)
	}
	if string(noID) == string(a) {
		t.Fatalf("expected event_id to be cleared for the hash preimage")
	}

	// The original header must not have been mutated.
	if len(h.GetEventId()) != DigestLen {
		t.Fatalf("canonicalHeaderBytes mutated the input header")
	}
}

func TestHashPreimageMatchesComputeEventID(t *testing.T) {
	h := sampleHeader()
	body := []byte("xyz")
	id, err := ComputeEventID(h, body)
	if err != nil {
		t.Fatalf("compute: %v", err)
	}
	pre, err := HashPreimage(h, body)
	if err != nil {
		t.Fatalf("preimage: %v", err)
	}
	if string(id) != string(Blake2b256(pre)) {
		t.Fatalf("ComputeEventID disagrees with Blake2b256(HashPreimage)")
	}
	// Sanity: preimage is header(no id) || body.
	headerNoID, _ := canonicalHeaderBytes(h, false)
	want := append(append([]byte{}, headerNoID...), body...)
	if string(pre) != string(want) {
		t.Fatalf("hash preimage concatenation order mismatch")
	}
	_ = proto.Message(h)
}
