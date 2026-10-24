package cache

import (
	"context"
	"path/filepath"
	"testing"

	resiliencev1 "github.com/resilience-network/aws13/node/gen/resilience/v1"
	"github.com/resilience-network/aws13/node/internal/events"

	"crypto/ed25519"
)

func mustKey(t *testing.T) ed25519.PrivateKey {
	t.Helper()
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("key: %v", err)
	}
	return priv
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

func TestVerifyBeforeStoreRejectsInvalid(t *testing.T) {
	c := New()
	priv := mustKey(t)
	ev := mkEvent(t, priv, 1, "ok")
	ev.Body = []byte("tampered") // invalidate

	applied, rejected, err := c.Push(context.Background(), []*resiliencev1.SignedEvent{ev})
	if err != nil {
		t.Fatalf("push: %v", err)
	}
	if len(applied) != 0 {
		t.Fatalf("expected 0 applied, got %d", len(applied))
	}
	if len(rejected) != 1 {
		t.Fatalf("expected 1 rejected, got %d", len(rejected))
	}
	if c.Len() != 0 {
		t.Fatalf("invalid event must not be stored; len=%d", c.Len())
	}
}

func TestDedupByContentHash(t *testing.T) {
	c := New()
	priv := mustKey(t)
	ev := mkEvent(t, priv, 5, "dup")

	_, _, _ = c.Push(context.Background(), []*resiliencev1.SignedEvent{ev})
	applied, rejected, err := c.Push(context.Background(), []*resiliencev1.SignedEvent{ev})
	if err != nil {
		t.Fatalf("push: %v", err)
	}
	if len(rejected) != 0 {
		t.Fatalf("dup should not be rejected")
	}
	if len(applied) != 1 {
		t.Fatalf("dup should still be applied, got %d", len(applied))
	}
	if c.Len() != 1 {
		t.Fatalf("dedup failed, len=%d", c.Len())
	}
}

func TestHighWaterAndPullAbove(t *testing.T) {
	c := New()
	priv := mustKey(t)
	e1 := mkEvent(t, priv, 1, "a")
	e2 := mkEvent(t, priv, 2, "b")
	e3 := mkEvent(t, priv, 3, "c")
	if _, _, err := c.Push(context.Background(), []*resiliencev1.SignedEvent{e1, e2, e3}); err != nil {
		t.Fatalf("push: %v", err)
	}

	author := AuthorKey(priv.Public().(ed25519.PublicKey))
	hw, _ := c.HighWaterByAuthor(context.Background())
	if hw[author] != 3 {
		t.Fatalf("high water = %d, want 3", hw[author])
	}

	// Pull strictly above lamport 1 => events 2 and 3.
	above, err := c.PullAbove(context.Background(), map[string]uint64{author: 1}, 0)
	if err != nil {
		t.Fatalf("pull: %v", err)
	}
	if len(above) != 2 {
		t.Fatalf("expected 2 events above watermark 1, got %d", len(above))
	}
	for _, ev := range above {
		if ev.GetHeader().GetLamport() <= 1 {
			t.Fatalf("pull returned event at or below watermark")
		}
	}

	// Heads digest reports the head event id at the high water.
	heads, _ := c.Heads(context.Background())
	if len(heads) != 1 || heads[0].HighWater != 3 {
		t.Fatalf("unexpected heads: %+v", heads)
	}
	if heads[0].HeadEventID != IDKey(e3.GetHeader().GetEventId()) {
		t.Fatalf("head event id mismatch")
	}
}

func TestPersistenceReplay(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "events.log")
	priv := mustKey(t)

	c1, err := Open(path)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	e1 := mkEvent(t, priv, 1, "persist-1")
	e2 := mkEvent(t, priv, 2, "persist-2")
	if _, _, err := c1.Push(context.Background(), []*resiliencev1.SignedEvent{e1, e2}); err != nil {
		t.Fatalf("push: %v", err)
	}
	if err := c1.Close(); err != nil {
		t.Fatalf("close: %v", err)
	}

	c2, err := Open(path)
	if err != nil {
		t.Fatalf("reopen: %v", err)
	}
	defer c2.Close()
	if c2.Len() != 2 {
		t.Fatalf("expected 2 replayed events, got %d", c2.Len())
	}
	if _, ok := c2.Get(context.Background(), e1.GetHeader().GetEventId()); !ok {
		t.Fatalf("replayed cache missing e1")
	}
}
