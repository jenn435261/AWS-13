package syncserver

import (
	"crypto/sha256"
	"encoding/hex"
	"sync"
	"time"
)

// blobStore is a content-addressed, in-memory store for opaque encrypted
// attachment blobs (photos, audio) served over local Wi-Fi. Exactly like the
// cloud blob store, it holds only ciphertext keyed by the SHA-256 of that
// ciphertext; the decryption key rides inside the end-to-end-encrypted message
// and never reaches the node. A stored blob is useless to anyone but the
// recipient.
//
// Abuse guards: a per-blob size cap (handler), a content-hash match on write,
// a 7-day purge, and a coarse per-caller rate limit.
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

func newBlobStore(ttl time.Duration) *blobStore {
	return &blobStore{
		blob: make(map[string]blobEntry),
		ttl:  ttl,
		now:  time.Now,
	}
}

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

func (b *blobStore) count() int {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.purgeLocked()
	return len(b.blob)
}

// rateLimiter is a fixed-window write counter keyed by caller.
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
