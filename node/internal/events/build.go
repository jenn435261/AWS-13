package events

import (
	"crypto/ed25519"

	resiliencev1 "github.com/resilience-network/aws13/node/gen/resilience/v1"
)

// BuildSignedEvent constructs a fully-formed, content-addressed, signed event
// using the exact recipe the Dart EventFactory uses:
//
//  1. fill the header (event_id left empty for now)
//  2. event_id  = BLAKE2b-256(canonicalHeader(no id) || body)
//  3. signature = Ed25519(priv).sign(canonicalHeader(with id) || body)
//
// It is primarily used by tests and tooling. The node never builds events on
// behalf of clients; it only verifies them. The passed header is cloned so the
// caller's value is not mutated.
func BuildSignedEvent(header *resiliencev1.EventHeader, body []byte, priv ed25519.PrivateKey) (*resiliencev1.SignedEvent, error) {
	h := cloneHeader(header)
	h.AuthorPubkey = priv.Public().(ed25519.PublicKey)
	h.EventId = nil

	id, err := ComputeEventID(h, body)
	if err != nil {
		return nil, err
	}
	h.EventId = id

	preimage, err := SignaturePreimage(h, body)
	if err != nil {
		return nil, err
	}
	sig := ed25519.Sign(priv, preimage)

	return &resiliencev1.SignedEvent{
		Header:    h,
		Body:      body,
		Signature: sig,
	}, nil
}

func cloneHeader(h *resiliencev1.EventHeader) *resiliencev1.EventHeader {
	if h == nil {
		return &resiliencev1.EventHeader{}
	}
	return &resiliencev1.EventHeader{
		EventId:       cloneBytes(h.GetEventId()),
		Type:          h.GetType(),
		AuthorPubkey:  cloneBytes(h.GetAuthorPubkey()),
		Lamport:       h.GetLamport(),
		PrevEventId:   cloneBytes(h.GetPrevEventId()),
		DependsOn:     h.GetDependsOn(),
		CreatedAtMs:   h.GetCreatedAtMs(),
		SchemaVersion: h.GetSchemaVersion(),
		H3Cell:        h.GetH3Cell(),
	}
}

func cloneBytes(b []byte) []byte {
	if b == nil {
		return nil
	}
	out := make([]byte, len(b))
	copy(out, b)
	return out
}
