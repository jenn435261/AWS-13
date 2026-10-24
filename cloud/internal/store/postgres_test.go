package store

import (
	"context"
	"crypto/ed25519"
	"os"
	"testing"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/events"
)

// TestPostgresStoreIntegration exercises the real PostgresStore against a live
// database. It is gated behind RESILIENCE_PG_DSN and skipped when unset, so the
// default `go test ./...` run never requires Postgres.
func TestPostgresStoreIntegration(t *testing.T) {
	dsn := os.Getenv("RESILIENCE_PG_DSN")
	if dsn == "" {
		t.Skip("RESILIENCE_PG_DSN not set; skipping Postgres integration test")
	}

	ctx := context.Background()
	pg, err := OpenPostgres(dsn)
	if err != nil {
		t.Fatalf("open postgres: %v", err)
	}
	defer pg.Close()

	if err := pg.Migrate(ctx); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	pub, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("keygen: %v", err)
	}
	h := &resiliencev1.EventHeader{
		Type:          resiliencev1.EventType_EVENT_TYPE_RESOURCE_CREATED,
		Lamport:       10,
		CreatedAtMs:   1_700_000_000_000,
		SchemaVersion: 1,
	}
	ev, err := events.BuildSignedEvent(h, []byte("pg-body"), priv)
	if err != nil {
		t.Fatalf("build: %v", err)
	}

	applied, rejected, err := pg.Push(ctx, []*resiliencev1.SignedEvent{ev})
	if err != nil {
		t.Fatalf("push: %v", err)
	}
	if len(applied) != 1 || len(rejected) != 0 {
		t.Fatalf("expected 1 applied / 0 rejected, got %d/%d", len(applied), len(rejected))
	}

	got, ok, err := pg.Get(ctx, ev.GetHeader().GetEventId())
	if err != nil || !ok {
		t.Fatalf("get: ok=%v err=%v", ok, err)
	}
	if string(got.GetBody()) != "pg-body" {
		t.Fatalf("body mismatch")
	}

	hw, err := pg.HighWaterByAuthor(ctx)
	if err != nil {
		t.Fatalf("highwater: %v", err)
	}
	if hw[AuthorKey(pub)] != 10 {
		t.Fatalf("expected high water 10, got %d", hw[AuthorKey(pub)])
	}

	pulled, err := pg.PullByAuthorFrom(ctx, map[string]uint64{AuthorKey(pub): 0}, 0)
	if err != nil {
		t.Fatalf("pull: %v", err)
	}
	if len(pulled) != 1 {
		t.Fatalf("expected 1 pulled, got %d", len(pulled))
	}
}
