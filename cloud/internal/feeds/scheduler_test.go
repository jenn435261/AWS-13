package feeds

import (
	"context"
	"crypto/ed25519"
	"errors"
	"io"
	"log/slog"
	"testing"

	"github.com/resilience-network/aws13/cloud/internal/store"
)

// fixtureFetcher maps a feed URL to canned fixture bytes, so the scheduler runs
// with NO live network. An unknown URL returns an error (simulating a down
// feed), which the scheduler must survive.
type fixtureFetcher struct {
	byURL map[string][]byte
}

func (f *fixtureFetcher) Fetch(_ context.Context, url string) ([]byte, error) {
	b, ok := f.byURL[url]
	if !ok {
		return nil, errors.New("no fixture for url")
	}
	return b, nil
}

func newFixtureScheduler(t *testing.T, st Pusher, in *Ingestor) *Scheduler {
	t.Helper()
	fs := Registry()
	feedList := []Feed{fs[SourceNWS], fs[SourceUSGS], fs[SourceWildfire], fs[SourceFEMA], fs[SourceGDACS]}
	byURL := map[string][]byte{}
	for _, f := range feedList {
		byURL[f.URL()] = readFixture(t, string(f.Source())+".json")
	}
	// Add one feed whose URL has no fixture to prove a failing feed is skipped.
	sched := NewScheduler(feedList, &fixtureFetcher{byURL: byURL}, in, st,
		slog.New(slog.NewTextHandler(io.Discard, nil)), 0)
	sched.now = func() int64 { return 1769300000000 }
	return sched
}

func TestSchedulerRunOnceIngestsAndDedups(t *testing.T) {
	seed := make([]byte, ed25519.SeedSize)
	priv := ed25519.NewKeyFromSeed(seed)
	in := NewIngestor(priv, 3600_000)
	st := store.NewMemStore()
	sched := newFixtureScheduler(t, st, in)

	ctx := context.Background()
	applied, err := sched.RunOnce(ctx)
	if err != nil {
		t.Fatalf("run once: %v", err)
	}
	if applied == 0 {
		t.Fatal("expected some alerts applied")
	}

	// A second identical pass must dedup entirely (byte-identical events, same
	// nowMs) — zero newly-applied beyond the first set is the signal. MemStore
	// counts a re-push of an existing id as applied, so instead assert the pull
	// count did not grow.
	before, err := st.PullByAuthorFrom(ctx, nil, 0)
	if err != nil {
		t.Fatalf("pull: %v", err)
	}
	if _, err := sched.RunOnce(ctx); err != nil {
		t.Fatalf("run once 2: %v", err)
	}
	after, err := st.PullByAuthorFrom(ctx, nil, 0)
	if err != nil {
		t.Fatalf("pull 2: %v", err)
	}
	if len(after) != len(before) {
		t.Fatalf("re-ingest created duplicates: before=%d after=%d", len(before), len(after))
	}
}

func TestSchedulerSurvivesFailingFeed(t *testing.T) {
	seed := make([]byte, ed25519.SeedSize)
	priv := ed25519.NewKeyFromSeed(seed)
	in := NewIngestor(priv, 3600_000)
	st := store.NewMemStore()

	// Only provide a fixture for NWS; the other four URLs will fail to fetch.
	nws := NewNWS()
	byURL := map[string][]byte{nws.URL(): readFixture(t, "nws.json")}
	sched := NewScheduler(
		[]Feed{nws, NewUSGS(), NewWildfire(), NewFEMA(), NewGDACS()},
		&fixtureFetcher{byURL: byURL}, in, st,
		slog.New(slog.NewTextHandler(io.Discard, nil)), 0)
	sched.now = func() int64 { return 1769300000000 }

	applied, err := sched.RunOnce(context.Background())
	if err != nil {
		t.Fatalf("run once: %v", err)
	}
	if applied != 2 { // the 2 NWS alerts with geometry
		t.Fatalf("applied = %d, want 2 (only NWS fixture provided)", applied)
	}
}
