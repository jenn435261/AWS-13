package api

import (
	"crypto/sha256"
	"encoding/hex"
	"sync"
	"time"
)

// blobStore is a content-addressed, in-memory store for opaque encrypted
// attachment blobs (photos, audio). It is deliberately dumb: it holds only
// ciphertext, keyed by the SHA-256 of that ciphertext. The server never holds
// the decryption key (that key travels only inside the end-to-end-encrypted
// message), so a stored blob is useless to anyone but the recipient.
//
// Abuse guards:
//   - a per-blob size cap (enforced by the handler before Put),
//   - the SHA-256 of the stored bytes MUST equal the key, so a client cannot
//     poison an address with mismatched content,
//   - a 7-day purge so storage cannot grow without bound,
//   - a coarse rate limit (see rateLimiter) applied by the handler.
type blobStore struct {
	mu   sync.Mutex
	blob map[string]blobEntry
	ttl  time.Duration
	now  func() time.Time
}

type blobEntry struct {
	data     []byte
	storedAt time.Time
}

// newBlobStore returns an empty blob store with the given time-to-live.
func newBlobStore(ttl time.Duration) *blobStore {
	return &blobStore{
		blob: make(map[string]blobEntry),
		ttl:  ttl,
		now:  time.Now,
	}
}

// put stores data under its content hash. It returns the computed hex SHA-256
// and false when the supplied wantHash does not match the content (the caller
// rejects the request in that case). Storing is idempotent.
func (b *blobStore) put(wantHash string, data []byte) (gotHash string, ok bool) {
	sum := sha256.Sum256(data)
	gotHash = hex.EncodeToString(sum[:])
	if wantHash != gotHash {
		return gotHash, false
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	b.purgeLocked()
	b.blob[gotHash] = blobEntry{data: data, storedAt: b.now()}
	return gotHash, true
}

// get returns the stored bytes for hash, or nil/false when absent or expired.
func (b *blobStore) get(hash string) ([]byte, bool) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.purgeLocked()
	e, ok := b.blob[hash]
	if !ok {
		return nil, false
	}
	return e.data, true
}

// purgeLocked removes entries older than the TTL. Caller holds the lock.
func (b *blobStore) purgeLocked() {
	if b.ttl <= 0 {
		return
	}
	cutoff := b.now().Add(-b.ttl)
	for k, e := range b.blob {
		if e.storedAt.Before(cutoff) {
			delete(b.blob, k)
		}
	}
}

// count returns the number of stored (non-expired) blobs. Test helper.
func (b *blobStore) count() int {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.purgeLocked()
	return len(b.blob)
}

// rateLimiter is a tiny fixed-window counter keyed by caller (client key or
// remote address). It caps how many blob writes a single caller can make in a
// window, a coarse abuse guard that never blocks reads.
type rateLimiter struct {
	mu     sync.Mutex
	window time.Duration
	limit  int
	hits   map[string]*windowCount
	now    func() time.Time
}

type windowCount struct {
	start time.Time
	n     int
}

func newRateLimiter(limit int, window time.Duration) *rateLimiter {
	return &rateLimiter{
		window: window,
		limit:  limit,
		hits:   make(map[string]*windowCount),
		now:    time.Now,
	}
}

// allow reports whether caller may perform another write now, and records it.
func (r *rateLimiter) allow(caller string) bool {
	if r.limit <= 0 {
		return true
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	now := r.now()
	wc, ok := r.hits[caller]
	if !ok || now.Sub(wc.start) >= r.window {
		r.hits[caller] = &windowCount{start: now, n: 1}
		return true
	}
	if wc.n >= r.limit {
		return false
	}
	wc.n++
	return true
}
