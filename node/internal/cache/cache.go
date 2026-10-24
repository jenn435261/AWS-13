// Package cache is the node's local event store: verify-before-store, content
// -hash dedup, per-author high-water tracking, and pull-above-watermark. It is
// an in-memory implementation (concurrency-safe) with an optional append-only
// file log so events survive a restart. It depends only on the node's own
// events package and generated protobuf types — never on the cloud module.
package cache

import (
	"context"
	"encoding/hex"
	"os"
	"sort"
	"sync"

	resiliencev1 "github.com/resilience-network/aws13/node/gen/resilience/v1"
	"github.com/resilience-network/aws13/node/internal/events"
	"google.golang.org/protobuf/proto"
)

// AuthorKey returns the canonical map key for an author public key.
func AuthorKey(pub []byte) string { return hex.EncodeToString(pub) }

// IDKey returns the canonical map key for an event id.
func IDKey(id []byte) string { return hex.EncodeToString(id) }

// Head is a per-author high-water digest entry: the author key (hex), the
// highest lamport seen for that author, and the event id of that highest event.
type Head struct {
	Author     string `json:"author"`
	HighWater  uint64 `json:"high_water"`
	HeadEventID string `json:"head_event_id"`
}

// Cache is a concurrency-safe local event store.
type Cache struct {
	mu        sync.RWMutex
	byID      map[string]*resiliencev1.SignedEvent // event_id hex -> event
	byAuthor  map[string][]string                  // author hex -> ordered event_id hex
	highWater map[string]uint64                    // author hex -> max lamport
	headID    map[string]string                    // author hex -> event id hex of highest lamport

	// log is an optional append-only writer; when non-nil every newly stored
	// (verified, non-duplicate) event is appended as a length-prefixed proto
	// record so the cache can be rebuilt on restart.
	log *os.File
}

// New returns an empty in-memory cache with no persistence.
func New() *Cache {
	return &Cache{
		byID:      make(map[string]*resiliencev1.SignedEvent),
		byAuthor:  make(map[string][]string),
		highWater: make(map[string]uint64),
		headID:    make(map[string]string),
	}
}

// Open returns a cache backed by an append-only log file at path. Existing
// records are replayed into memory (verify-before-store still applies), and
// subsequent stores are appended. An empty path yields an in-memory cache.
func Open(path string) (*Cache, error) {
	c := New()
	if path == "" {
		return c, nil
	}
	// Replay existing records if the file exists.
	if data, err := os.ReadFile(path); err == nil {
		for _, ev := range decodeLog(data) {
			// Replayed events go through the same verify-before-store path.
			_, _, _ = c.store(ev, false)
		}
	} else if !os.IsNotExist(err) {
		return nil, err
	}
	f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return nil, err
	}
	c.log = f
	return c, nil
}

// Close flushes and closes the append log, if any.
func (c *Cache) Close() error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.log != nil {
		err := c.log.Close()
		c.log = nil
		return err
	}
	return nil
}

// Push verifies and stores each event. Invalid events are returned in rejected
// and never stored. Duplicates (same event_id already present) count as applied
// without being stored twice. Returned ids are the raw 32-byte event ids.
func (c *Cache) Push(ctx context.Context, evs []*resiliencev1.SignedEvent) (applied [][]byte, rejected [][]byte, err error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	for _, ev := range evs {
		id, ok, perr := c.store(ev, true)
		if perr != nil {
			return applied, rejected, perr
		}
		if !ok {
			rejected = append(rejected, eventID(ev))
			continue
		}
		applied = append(applied, id)
	}
	return applied, rejected, nil
}

// store verifies ev and, if valid, inserts it (deduped) and optionally appends
// it to the log. It returns the raw event id and whether the event was accepted
// (verified). Caller must hold c.mu. appendLog controls whether a new record is
// written (false during replay to avoid rewriting the log).
func (c *Cache) store(ev *resiliencev1.SignedEvent, appendLog bool) ([]byte, bool, error) {
	ok, _ := events.VerifyEvent(ev)
	if !ok {
		return eventID(ev), false, nil
	}

	id := ev.GetHeader().GetEventId()
	idKey := IDKey(id)
	author := AuthorKey(ev.GetHeader().GetAuthorPubkey())
	lamport := ev.GetHeader().GetLamport()

	if _, exists := c.byID[idKey]; exists {
		// Content-hash dedup: already stored, still counts as applied.
		return id, true, nil
	}

	c.byID[idKey] = ev
	c.byAuthor[author] = append(c.byAuthor[author], idKey)
	if lamport >= c.highWater[author] || c.headID[author] == "" {
		if lamport >= c.highWater[author] {
			c.highWater[author] = lamport
			c.headID[author] = idKey
		}
	}

	if appendLog && c.log != nil {
		if _, err := c.log.Write(encodeRecord(ev)); err != nil {
			return id, true, err
		}
	}
	return id, true, nil
}

// PullAbove returns events whose lamport is strictly greater than the supplied
// per-author watermark. When from is empty, every stored event is returned.
// Results are ordered by (author, lamport, event_id) for determinism; limit <=
// 0 means no limit.
func (c *Cache) PullAbove(ctx context.Context, from map[string]uint64, limit int) ([]*resiliencev1.SignedEvent, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	// Always scan every author we hold. Authors present in `from` use their
	// supplied watermark; authors absent from `from` (including authors the
	// caller has never heard of) use watermark 0, so the caller receives every
	// event it is missing. This is what lets two phones reconcile through the
	// node: a phone that only knows its own author id still pulls down every
	// other author's events.
	var authors []string
	for a := range c.byAuthor {
		authors = append(authors, a)
	}
	sort.Strings(authors)

	var out []*resiliencev1.SignedEvent
	for _, author := range authors {
		watermark := from[author] // 0 when absent
		ids := append([]string(nil), c.byAuthor[author]...)
		sort.Slice(ids, func(i, j int) bool {
			li := c.byID[ids[i]].GetHeader().GetLamport()
			lj := c.byID[ids[j]].GetHeader().GetLamport()
			if li != lj {
				return li < lj
			}
			return ids[i] < ids[j]
		})
		for _, idKey := range ids {
			ev := c.byID[idKey]
			if ev.GetHeader().GetLamport() <= watermark {
				continue
			}
			out = append(out, ev)
			if limit > 0 && len(out) >= limit {
				return out, nil
			}
		}
	}
	return out, nil
}

// Heads returns the per-author high-water digest, sorted by author key.
func (c *Cache) Heads(ctx context.Context) ([]Head, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	heads := make([]Head, 0, len(c.highWater))
	for a, hw := range c.highWater {
		heads = append(heads, Head{Author: a, HighWater: hw, HeadEventID: c.headID[a]})
	}
	sort.Slice(heads, func(i, j int) bool { return heads[i].Author < heads[j].Author })
	return heads, nil
}

// HighWaterByAuthor returns a copy of the per-author high-water map.
func (c *Cache) HighWaterByAuthor(ctx context.Context) (map[string]uint64, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	out := make(map[string]uint64, len(c.highWater))
	for k, v := range c.highWater {
		out[k] = v
	}
	return out, nil
}

// All returns every stored event ordered deterministically by (author, lamport,
// event_id). Useful for folding current state.
func (c *Cache) All(ctx context.Context) ([]*resiliencev1.SignedEvent, error) {
	return c.PullAbove(ctx, nil, 0)
}

// Get returns the event with the given id, if present.
func (c *Cache) Get(ctx context.Context, id []byte) (*resiliencev1.SignedEvent, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	ev, ok := c.byID[IDKey(id)]
	return ev, ok
}

// Len returns the number of distinct stored events.
func (c *Cache) Len() int {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return len(c.byID)
}

func eventID(ev *resiliencev1.SignedEvent) []byte {
	if ev == nil || ev.GetHeader() == nil {
		return nil
	}
	return ev.GetHeader().GetEventId()
}

// --- append log encoding: a sequence of [uint32 big-endian length][proto] ---

func encodeRecord(ev *resiliencev1.SignedEvent) []byte {
	b, err := proto.Marshal(ev)
	if err != nil {
		return nil
	}
	n := len(b)
	rec := make([]byte, 4+n)
	rec[0] = byte(n >> 24)
	rec[1] = byte(n >> 16)
	rec[2] = byte(n >> 8)
	rec[3] = byte(n)
	copy(rec[4:], b)
	return rec
}

func decodeLog(data []byte) []*resiliencev1.SignedEvent {
	var out []*resiliencev1.SignedEvent
	for len(data) >= 4 {
		n := int(data[0])<<24 | int(data[1])<<16 | int(data[2])<<8 | int(data[3])
		if n < 0 || 4+n > len(data) {
			break // truncated/corrupt tail: stop replay
		}
		ev := &resiliencev1.SignedEvent{}
		if err := proto.Unmarshal(data[4:4+n], ev); err == nil {
			out = append(out, ev)
		}
		data = data[4+n:]
	}
	return out
}
