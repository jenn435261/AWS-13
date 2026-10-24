package queue

import (
	"context"
	"strconv"
	"sync"
)

// MemQueue is an in-memory Queue for local runs and tests. It hands out
// monotonic string handles and drops a message once deleted.
type MemQueue struct {
	mu       sync.Mutex
	next     uint64
	pending  map[string][]byte
	incoming []Message
}

var _ Queue = (*MemQueue)(nil)

// NewMemQueue returns an empty MemQueue.
func NewMemQueue() *MemQueue {
	return &MemQueue{pending: make(map[string][]byte)}
}

// Enqueue adds a payload to the queue, returning its handle.
func (q *MemQueue) Enqueue(body []byte) string {
	q.mu.Lock()
	defer q.mu.Unlock()
	q.next++
	handle := strconv.FormatUint(q.next, 10)
	q.pending[handle] = body
	q.incoming = append(q.incoming, Message{Body: body, Handle: handle})
	return handle
}

// Receive returns and clears all currently-available messages. Messages remain
// "in flight" (in pending) until Delete is called.
func (q *MemQueue) Receive(ctx context.Context) ([]Message, error) {
	q.mu.Lock()
	defer q.mu.Unlock()
	if len(q.incoming) == 0 {
		return nil, nil
	}
	out := q.incoming
	q.incoming = nil
	return out, nil
}

// Delete removes messages by handle so they are not redelivered.
func (q *MemQueue) Delete(ctx context.Context, handles ...string) error {
	q.mu.Lock()
	defer q.mu.Unlock()
	for _, h := range handles {
		delete(q.pending, h)
	}
	return nil
}

// Len reports how many messages remain in flight (received-but-not-deleted plus
// not-yet-received).
func (q *MemQueue) Len() int {
	q.mu.Lock()
	defer q.mu.Unlock()
	return len(q.pending)
}
