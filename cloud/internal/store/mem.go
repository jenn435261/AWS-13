package store

import (
	"context"
	"sort"
	"sync"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/events"
)

// MemStore is an in-memory, concurrency-safe Store. It verifies every event
// before storing (verify-before-store), dedups by content hash (event_id), and
// tracks a per-author high-water lamport. It is fully featured for local
// development and testing and requires zero external dependencies.
type MemStore struct {
	mu        sync.RWMutex
	byID      map[string]*resiliencev1.SignedEvent // event_id hex -> event
	byAuthor  map[string][]string                  // author hex -> ordered event_id hex
	highWater map[string]uint64                    // author hex -> max lamport
}

// NewMemStore returns an empty MemStore.
func NewMemStore() *MemStore {
	return &MemStore{
		byID:      make(map[string]*resiliencev1.SignedEvent),
		byAuthor:  make(map[string][]string),
		highWater: make(map[string]uint64),
	}
}

var _ Store = (*MemStore)(nil)

// Push verifies and stores each event. Invalid events are returned in rejected
// and never stored. Duplicates (same event_id already stored) are counted as
// applied without being stored twice.
func (m *MemStore) Push(ctx context.Context, evs []*resiliencev1.SignedEvent) (applied [][]byte, rejected [][]byte, err error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	for _, ev := range evs {
		ok, _ := events.VerifyEvent(ev)
		if !ok {
			rejected = append(rejected, eventID(ev))
			continue
		}

		id := ev.GetHeader().GetEventId()
		idKey := IDKey(id)
		author := AuthorKey(ev.GetHeader().GetAuthorPubkey())
		lamport := ev.GetHeader().GetLamport()

		if _, exists := m.byID[idKey]; exists {
			// Content-hash dedup: already stored, still counts as applied.
			applied = append(applied, id)
			continue
		}

		m.byID[idKey] = ev
		m.byAuthor[author] = append(m.byAuthor[author], idKey)
		if lamport > m.highWater[author] {
			m.highWater[author] = lamport
		}
		applied = append(applied, id)
	}
	return applied, rejected, nil
}

// PullByAuthorFrom returns events with lamport strictly greater than the
// supplied watermark per author. When from is empty, every stored event is
// returned. Results are ordered by (author, lamport, event_id) for
// determinism. limit <= 0 means no limit.
func (m *MemStore) PullByAuthorFrom(ctx context.Context, from map[string]uint64, limit int) ([]*resiliencev1.SignedEvent, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	// Decide which authors to scan.
	var authors []string
	if len(from) == 0 {
		for a := range m.byAuthor {
			authors = append(authors, a)
		}
	} else {
		for a := range from {
			if _, ok := m.byAuthor[a]; ok {
				authors = append(authors, a)
			}
		}
	}
	sort.Strings(authors)

	var out []*resiliencev1.SignedEvent
	for _, author := range authors {
		watermark := from[author] // 0 when absent
		ids := append([]string(nil), m.byAuthor[author]...)
		// Order this author's events by lamport then id for determinism.
		sort.Slice(ids, func(i, j int) bool {
			li := m.byID[ids[i]].GetHeader().GetLamport()
			lj := m.byID[ids[j]].GetHeader().GetLamport()
			if li != lj {
				return li < lj
			}
			return ids[i] < ids[j]
		})
		for _, idKey := range ids {
			ev := m.byID[idKey]
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

// HighWaterByAuthor returns a copy of the per-author high-water map.
func (m *MemStore) HighWaterByAuthor(ctx context.Context) (map[string]uint64, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make(map[string]uint64, len(m.highWater))
	for k, v := range m.highWater {
		out[k] = v
	}
	return out, nil
}

// Get returns the event with the given id.
func (m *MemStore) Get(ctx context.Context, id []byte) (*resiliencev1.SignedEvent, bool, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	ev, ok := m.byID[IDKey(id)]
	return ev, ok, nil
}

// eventID returns the event id if it can be read, else nil.
func eventID(ev *resiliencev1.SignedEvent) []byte {
	if ev == nil || ev.GetHeader() == nil {
		return nil
	}
	return ev.GetHeader().GetEventId()
}
