// Package events implements content-hashing and signature verification for
// Resilience Network events, matching the Dart client exactly.
//
// # The recipe (must match app/lib/core/canonical.dart + event_factory.dart)
//
// Every event is a SignedEvent{header, body, signature}. Identity and
// authenticity are derived from two preimages built from the canonical
// (deterministic) protobuf encoding of the EventHeader concatenated with the
// raw body bytes:
//
//   - hash preimage      = canonicalHeader(event_id CLEARED) || body
//   - signature preimage = canonicalHeader(event_id SET)     || body
//
// From these:
//
//   - event_id  = BLAKE2b-256(hash preimage)                  (32 bytes)
//   - signature = Ed25519(author_pubkey).sign(signature preimage) (64 bytes)
//
// The Dart client uses protobuf-dart's writeToBuffer(), which emits set fields
// in ascending tag order with the single canonical wire encoding per type, and
// clears unknown fields first. We reproduce that here with
// proto.MarshalOptions{Deterministic: true} over a clone of the header (so we
// never mutate the caller's message) after clearing the event_id for the hash
// preimage. Deterministic marshaling in google.golang.org/protobuf emits fields
// in field-number order, matching protobuf-dart's tag-ordered output.
//
// VerifyEvent performs the explicit, fail-closed checks the server must run
// before trusting (and storing) any client-supplied event. The server is
// authoritative for what it accepts: it never trusts the client-supplied
// event_id or signature without recomputing and re-verifying.
package events

import (
	"bytes"
	"crypto/ed25519"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"golang.org/x/crypto/blake2b"
	"google.golang.org/protobuf/proto"
)

// DigestLen is the BLAKE2b-256 output length in bytes (the event_id length).
const DigestLen = 32

// deterministic marshaling options shared by every canonical encode. Matches
// the determinism guarantees protobuf-dart's writeToBuffer() provides for these
// messages (ascending tag order, single canonical wire encoding).
var canonicalOpts = proto.MarshalOptions{Deterministic: true}

// canonicalHeaderBytes returns the canonical (deterministic) protobuf encoding
// of header. When includeID is false the event_id field (tag 1) is cleared
// before encoding, producing the hash preimage header; when true the header is
// encoded as-is (expected to already carry the computed event_id), producing
// the signature preimage header.
//
// The input header is never mutated: we operate on a clone.
func canonicalHeaderBytes(header *resiliencev1.EventHeader, includeID bool) ([]byte, error) {
	clone := proto.Clone(header).(*resiliencev1.EventHeader)
	if !includeID {
		clone.EventId = nil
	}
	// Discard unknown fields before marshaling so the canonical preimage commits
	// to exactly the known-field projection. This matches the Dart client, which
	// clears unknownFields before hashing, and keeps the cross-language content
	// hash identical as the schema evolves (a newer client may set header fields
	// an older verifier doesn't know; both sides must hash the same bytes).
	clone.ProtoReflect().SetUnknown(nil)
	return canonicalOpts.Marshal(clone)
}

// HashPreimage returns the canonical hash preimage: header(without id) || body.
// BLAKE2b-256 of this is the event_id.
func HashPreimage(header *resiliencev1.EventHeader, body []byte) ([]byte, error) {
	head, err := canonicalHeaderBytes(header, false)
	if err != nil {
		return nil, err
	}
	return concat(head, body), nil
}

// SignaturePreimage returns the canonical signature preimage:
// header(with id) || body. This is exactly what Ed25519 signs / verifies.
func SignaturePreimage(header *resiliencev1.EventHeader, body []byte) ([]byte, error) {
	head, err := canonicalHeaderBytes(header, true)
	if err != nil {
		return nil, err
	}
	return concat(head, body), nil
}

// ComputeEventID returns BLAKE2b-256(HashPreimage(header, body)): the
// content-addressed event id. Does not mutate header.
func ComputeEventID(header *resiliencev1.EventHeader, body []byte) ([]byte, error) {
	preimage, err := HashPreimage(header, body)
	if err != nil {
		return nil, err
	}
	sum := Blake2b256(preimage)
	return sum, nil
}

// Blake2b256 returns the 32-byte BLAKE2b-256 digest of data (RFC 7693). This is
// a first-class 32-byte BLAKE2b (output length mixed into the IV), NOT a
// truncation of the 64-byte variant, matching the Dart DartBlake2b(32).
func Blake2b256(data []byte) []byte {
	h, err := blake2b.New(DigestLen, nil)
	if err != nil {
		// New only errors for an invalid size or key; DigestLen is a valid
		// constant and we pass no key, so this is unreachable.
		panic(err)
	}
	h.Write(data)
	return h.Sum(nil)
}

// VerifyEvent runs the explicit, fail-closed verification the authoritative
// server must perform before trusting an event. It returns (ok, reason). When
// ok is true reason is empty; otherwise reason explains the first failing
// check. It never panics on malformed input.
//
// Checks, in order (mirroring EventFactory.verifyEvent in the Dart client):
//  1. header present and type set (not EVENT_TYPE_UNSPECIFIED)
//  2. author_pubkey is a 32-byte Ed25519 key
//  3. signature is 64 bytes
//  4. event_id is 32 bytes and equals the recomputed content hash
//     (BLAKE2b-256(canonicalHeader(no id) || body)) — detects tampering
//  5. the signature is a valid Ed25519 signature by author_pubkey over
//     canonicalHeader(with id) || body
func VerifyEvent(ev *resiliencev1.SignedEvent) (bool, string) {
	if ev == nil {
		return false, "nil event"
	}
	header := ev.GetHeader()
	if header == nil {
		return false, "missing header"
	}
	if header.GetType() == resiliencev1.EventType_EVENT_TYPE_UNSPECIFIED {
		return false, "unspecified event type"
	}
	pub := header.GetAuthorPubkey()
	if len(pub) != ed25519.PublicKeySize {
		return false, "author_pubkey must be 32 bytes"
	}
	sig := ev.GetSignature()
	if len(sig) != ed25519.SignatureSize {
		return false, "signature must be 64 bytes"
	}
	if len(header.GetEventId()) != DigestLen {
		return false, "event_id must be 32 bytes"
	}

	body := ev.GetBody()

	// 4. Recompute the content hash and compare to the stored id.
	recomputed, err := ComputeEventID(header, body)
	if err != nil {
		return false, "failed to marshal header: " + err.Error()
	}
	if !bytes.Equal(recomputed, header.GetEventId()) {
		return false, "event_id does not match content hash"
	}

	// 5. Verify signature over header(with id) || body.
	preimage, err := SignaturePreimage(header, body)
	if err != nil {
		return false, "failed to marshal header: " + err.Error()
	}
	if !ed25519.Verify(ed25519.PublicKey(pub), preimage, sig) {
		return false, "invalid signature"
	}
	return true, ""
}

func concat(a, b []byte) []byte {
	out := make([]byte, 0, len(a)+len(b))
	out = append(out, a...)
	out = append(out, b...)
	return out
}
