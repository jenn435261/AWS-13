package gateway

import (
	"context"
	"crypto/ed25519"
	"sync"
	"testing"
	"time"

	resiliencev1 "github.com/resilience-network/aws13/node/gen/resilience/v1"
	"github.com/resilience-network/aws13/node/internal/cache"
	"github.com/resilience-network/aws13/node/internal/events"
)

// fakeCloud is an in-memory CloudClient. It records pushed events and serves
// them back (and any seeded remote events) on pull, honoring per-author
// watermarks like the real cloud.
type fakeCloud struct {
	mu       sync.Mutex
	store    *cache.Cache // reuse the cache as a correct push/pull engine
	pushed   int
	pullHits int
}

func newFakeCloud() *fakeCloud { return &fakeCloud{store: cache.New()} }

func (f *fakeCloud) Push(ctx context.Context, evs []*resiliencev1.SignedEvent) ([][]byte, [][]byte, error) {
	f.mu.Lock()
	f.pushed += len(evs)
	f.mu.Unlock()
	return f.store.Push(ctx, evs)
}

func (f *fakeCloud) Pull(ctx context.Context, from map[string]uint64) ([]*resiliencev1.SignedEvent, error) {
	f.mu.Lock()
	f.pullHits++
	f.mu.Unlock()
	return f.store.PullAbove(ctx, from, 0)
}

func (f *fakeCloud) seed(ctx context.Context, evs ...*resiliencev1.SignedEvent) {
	_, _, _ = f.store.Push(ctx, evs)
}

func mkEvent(t *testing.T, priv ed25519.PrivateKey, lamport uint64, body string) *resiliencev1.SignedEvent {
	t.Helper()
	h := &resiliencev1.EventHeader{
		Type:    resiliencev1.EventType_EVENT_TYPE_RESOURCE_CREATED,
		Lamport: lamport,
	}
	ev, err := events.BuildSignedEvent(h, []byte(body), priv)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	return ev
}

func newKey(t *testing.T) ed25519.PrivateKey {
	t.Helper()
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("key: %v", err)
	}
	return priv
}

func TestGatewayPushesUpAndPullsDown(t *testing.T) {
	ctx := context.Background()
	local := cache.New()
	cloud := newFakeCloud()

	// Local node has one event; cloud has a different remote event seeded.
	localKey := newKey(t)
	remoteKey := newKey(t)
	localEv := mkEvent(t, localKey, 1, "local-water")
	if _, _, err := local.Push(ctx, []*resiliencev1.SignedEvent{localEv}); err != nil {
		t.Fatalf("seed local: %v", err)
	}
	remoteEv := mkEvent(t, remoteKey, 1, "remote-shelter")
	cloud.seed(ctx, remoteEv)

	gw := New(local, Options{Cloud: cloud})
	if !gw.Enabled() {
		t.Fatalf("gateway with cloud must be enabled")
	}
	if err := gw.SyncOnce(ctx); err != nil {
		t.Fatalf("sync: %v", err)
	}

	// Cloud must have received the local event.
	if cloud.pushed == 0 {
		t.Fatalf("expected gateway to push local events up")
	}
	if _, ok := cloud.store.Get(ctx, localEv.GetHeader().GetEventId()); !ok {
		t.Fatalf("cloud missing the pushed local event")
	}

	// Local must have pulled the remote event down.
	if _, ok := local.Get(ctx, remoteEv.GetHeader().GetEventId()); !ok {
		t.Fatalf("local cache missing the pulled remote event")
	}
}

func TestGatewayDisabledIsNoOp(t *testing.T) {
	ctx := context.Background()
	local := cache.New()
	priv := newKey(t)
	ev := mkEvent(t, priv, 1, "water")
	if _, _, err := local.Push(ctx, []*resiliencev1.SignedEvent{ev}); err != nil {
		t.Fatalf("seed: %v", err)
	}

	gw := New(local, Options{}) // no cloud
	if gw.Enabled() {
		t.Fatalf("gateway without cloud must be disabled")
	}
	if err := gw.SyncOnce(ctx); err != nil {
		t.Fatalf("disabled sync must be a no-op, got err: %v", err)
	}

	// The node still serves its local events unchanged.
	if local.Len() != 1 {
		t.Fatalf("local cache changed while disabled; len=%d", local.Len())
	}

	// Run() with no cloud should return promptly on context cancel (the mesh is
	// the no-op bridge) and never error.
	rctx, cancel := context.WithTimeout(ctx, 200*time.Millisecond)
	defer cancel()
	done := make(chan error, 1)
	go func() { done <- gw.Run(rctx) }()
	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("disabled Run returned error: %v", err)
		}
	case <-time.After(2 * time.Second):
		t.Fatalf("disabled Run did not return after context cancel")
	}
}

func TestNopMeshIsUsedByDefault(t *testing.T) {
	gw := New(cache.New(), Options{})
	if gw.mesh == nil {
		t.Fatalf("mesh must default to NopMesh")
	}
	if gw.mesh.Name() != "nop-mesh" {
		t.Fatalf("default mesh name = %q, want nop-mesh", gw.mesh.Name())
	}
}
