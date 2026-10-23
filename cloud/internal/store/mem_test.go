package store

import (
	"context"
	"crypto/ed25519"
	"testing"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/events"
)

func buildEvent(t *testing.T, priv ed25519.PrivateKey, lamport uint64, body string) *resiliencev1.SignedEvent {
	t.Helper()
	h := &resiliencev1.EventHeader{
		Type:          resiliencev1.EventType_EVENT_TYPE_RESOURCE_CREATED,
		Lamport:       lamport,
		CreatedAtMs:   1_700_000_000_000 + int64(lamport),
		SchemaVersion: 1,
	}
	ev, err := events.BuildSignedEvent(h, []byte(body), priv)
	if err != nil {
		t.Fatalf("build event: %v", err)
	}
	return ev
}

func TestMemPushDedupByContentHash(t *testing.T) {
	_, priv := genKey(t)
	m := NewMemStore()
	ctx := context.Background()

	ev := buildEvent(t, priv, 1, "same")

	applied, rejected, err := m.Push(ctx, []*resiliencev1.SignedEvent{ev, ev})
	if err != nil {
		t.Fatalf("push: %v", err)
	}
	if len(rejected) != 0 {
		t.Fatalf("expected no rejects, got %d", len(rejected))
	}
	if len(applied) != 2 {
		t.Fatalf("expected both pushes counted as applied, got %d", len(applied))
	}

	// Only one copy actually stored.
	got, ok, err := m.Get(ctx, ev.GetHeader().GetEventId())
	if err != nil || !ok {
		t.Fatalf("get: ok=%v err=%v", ok, err)
	}
	if string(got.GetBody()) != "same" {
		t.Fatalf("stored body mismatch")
	}

	all, err := m.PullByAuthorFrom(ctx, nil, 0)
	if err != nil {
		t.Fatalf("pull: %v", err)
	}
	if len(all) != 1 {
		t.Fatalf("expected 1 stored event after dedup, got %d", len(all))
	}
}

func TestMemHighWaterByAuthor(t *testing.T) {
	pub, priv := genKey(t)
	m := NewMemStore()
	ctx := context.Background()

	for _, l := range []uint64{1, 5, 3} {
		if _, _, err := m.Push(ctx, []*resiliencev1.SignedEvent{buildEvent(t, priv, l, "b")}); err != nil {
			t.Fatalf("push: %v", err)
		}
	}

	hw, err := m.HighWaterByAuthor(ctx)
	if err != nil {
		t.Fatalf("highwater: %v", err)
	}
	key := AuthorKey(pub)
	if hw[key] != 5 {
		t.Fatalf("expected high water 5, got %d", hw[key])
	}
}

func TestMemPullAboveWatermark(t *testing.T) {
	pub, priv := genKey(t)
	m := NewMemStore()
	ctx := context.Background()

	for _, l := range []uint64{1, 2, 3, 4} {
		if _, _, err := m.Push(ctx, []*resiliencev1.SignedEvent{buildEvent(t, priv, l, "b")}); err != nil {
			t.Fatalf("push: %v", err)
		}
	}

	from := map[string]uint64{AuthorKey(pub): 2}
	got, err := m.PullByAuthorFrom(ctx, from, 0)
	if err != nil {
		t.Fatalf("pull: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("expected 2 events above watermark 2, got %d", len(got))
	}
	for _, ev := range got {
		if ev.GetHeader().GetLamport() <= 2 {
			t.Fatalf("pulled event at or below watermark: %d", ev.GetHeader().GetLamport())
		}
	}

	// Limit is respected.
	limited, err := m.PullByAuthorFrom(ctx, from, 1)
	if err != nil {
		t.Fatalf("pull limited: %v", err)
	}
	if len(limited) != 1 {
		t.Fatalf("expected limit 1, got %d", len(limited))
	}
}

func TestMemInvalidEventsRejectedNotStored(t *testing.T) {
	_, priv := genKey(t)
	m := NewMemStore()
	ctx := context.Background()

	valid := buildEvent(t, priv, 1, "ok")

	// Tamper a second event so verification fails.
	bad := buildEvent(t, priv, 2, "bad")
	bad.Body = []byte("tampered")

	applied, rejected, err := m.Push(ctx, []*resiliencev1.SignedEvent{valid, bad})
	if err != nil {
		t.Fatalf("push: %v", err)
	}
	if len(applied) != 1 {
		t.Fatalf("expected 1 applied, got %d", len(applied))
	}
	if len(rejected) != 1 {
		t.Fatalf("expected 1 rejected, got %d", len(rejected))
	}

	// The invalid event must not be retrievable.
	if _, ok, _ := m.Get(ctx, bad.GetHeader().GetEventId()); ok {
		t.Fatalf("invalid event should not have been stored")
	}
	// The valid event must be retrievable.
	if _, ok, _ := m.Get(ctx, valid.GetHeader().GetEventId()); !ok {
		t.Fatalf("valid event should have been stored")
	}
}

func genKey(t *testing.T) (ed25519.PublicKey, ed25519.PrivateKey) {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("generate key: %v", err)
	}
	return pub, priv
}
