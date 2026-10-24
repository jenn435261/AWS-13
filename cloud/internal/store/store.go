// Package store defines the authoritative event store abstraction and its
// implementations.
//
// The server is authoritative for what it accepts: every event is verified
// (signature + content hash) BEFORE it is persisted. Each Store implementation
// is responsible for calling events.VerifyEvent in Push and returning invalid
// events in the rejected set without storing them.
//
// Keys that identify an author are the author's Ed25519 public key, hex-encoded
// (lowercase), as produced by AuthorKey.
package store

import (
	"context"
	"encoding/hex"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
)

// Store is the authoritative event store. Implementations MUST verify every
// event before storing it (verify-before-store).
type Store interface {
	// Push verifies and stores a batch of events. It returns the event ids that
	// were accepted (applied) and the event ids that were rejected (failed
	// verification or otherwise not stored). Events whose id cannot be
	// determined (e.g. nil header) are rejected with a nil/empty id. Dedup is by
	// content hash (event_id): re-pushing an already-stored event counts as
	// applied but does not create a duplicate.
	Push(ctx context.Context, evs []*resiliencev1.SignedEvent) (applied [][]byte, rejected [][]byte, err error)

	// PullByAuthorFrom returns stored events whose lamport is strictly greater
	// than the watermark supplied for their author. The watermark map is keyed
	// by author pubkey hex (see AuthorKey); authors not present in the map are
	// treated as watermark 0 only if requested — implementations return events
	// for the requested authors. When from is empty, all authors are returned.
	// limit <= 0 means no limit.
	PullByAuthorFrom(ctx context.Context, from map[string]uint64, limit int) ([]*resiliencev1.SignedEvent, error)

	// HighWaterByAuthor returns the highest lamport stored per author, keyed by
	// author pubkey hex.
	HighWaterByAuthor(ctx context.Context) (map[string]uint64, error)

	// Get returns the stored event with the given id, if present.
	Get(ctx context.Context, id []byte) (*resiliencev1.SignedEvent, bool, error)
}

// AuthorKey returns the canonical map key for an author pubkey: lowercase hex.
func AuthorKey(authorPubkey []byte) string {
	return hex.EncodeToString(authorPubkey)
}

// IDKey returns the canonical map key for an event id: lowercase hex.
func IDKey(id []byte) string {
	return hex.EncodeToString(id)
}
