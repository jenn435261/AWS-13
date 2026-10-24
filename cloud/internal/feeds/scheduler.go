package feeds

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/store"
)

// Pusher is the minimal write side the scheduler needs: it stores signed events
// (verify-before-store is the store's responsibility). store.Store satisfies
// it.
type Pusher interface {
	Push(ctx context.Context, evs []*resiliencev1.SignedEvent) (applied [][]byte, rejected [][]byte, err error)
}

var _ Pusher = store.Store(nil)

// Fetcher fetches the raw bytes for one feed URL. It is an interface so the
// scheduler can be driven from fixtures in tests (NO live network) and from a
// real HTTP client in production.
type Fetcher interface {
	Fetch(ctx context.Context, url string) ([]byte, error)
}

// HTTPFetcher is the production Fetcher backed by net/http with a timeout.
type HTTPFetcher struct {
	Client    *http.Client
	UserAgent string
}

// NewHTTPFetcher returns an HTTPFetcher with a sane timeout and a descriptive
// User-Agent (NWS requires one).
func NewHTTPFetcher() *HTTPFetcher {
	return &HTTPFetcher{
		Client:    &http.Client{Timeout: 20 * time.Second},
		UserAgent: "resilience-network-cloud/1.0 (+https://github.com/resilience-network)",
	}
}

// Fetch GETs url and returns its body. Non-2xx responses are errors.
func (f *HTTPFetcher) Fetch(ctx context.Context, url string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	if f.UserAgent != "" {
		req.Header.Set("User-Agent", f.UserAgent)
	}
	req.Header.Set("Accept", "application/json, application/geo+json")
	resp, err := f.Client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 32<<20)) // 32 MiB cap
	if err != nil {
		return nil, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, &httpStatusError{code: resp.StatusCode}
	}
	return body, nil
}

type httpStatusError struct{ code int }

func (e *httpStatusError) Error() string { return "feeds: upstream status " + itoa(e.code) }

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var b [12]byte
	i := len(b)
	neg := n < 0
	if neg {
		n = -n
	}
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		b[i] = '-'
	}
	return string(b[i:])
}

// Scheduler fetches every configured feed, signs the records into cloud-signed
// EMERGENCY_ALERT events, and pushes them to the store. It is decoupled from the
// api service: it shares only the events, store and feeds packages. One pass is
// RunOnce; Run loops on an interval until the context is cancelled.
type Scheduler struct {
	feeds    []Feed
	fetch    Fetcher
	ingest   *Ingestor
	store    Pusher
	log      *slog.Logger
	interval time.Duration
	// lamport is a monotonic logical clock for the feed key, advanced across
	// passes so later ingests order after earlier ones.
	lamport atomic.Uint64
	// now is the clock source (overridable in tests).
	now func() int64

	// seen fingerprints an alert by its stable id so an unchanged upstream is
	// not re-signed into a fresh (higher-lamport) event each pass. Only new or
	// CHANGED alerts advance the lamport and get pushed. Keyed by alert_id.
	mu   sync.Mutex
	seen map[string]string
}

// NewScheduler builds a Scheduler. interval<=0 defaults to 15 minutes.
func NewScheduler(feeds []Feed, fetch Fetcher, ingest *Ingestor, st Pusher, log *slog.Logger, interval time.Duration) *Scheduler {
	if log == nil {
		log = slog.Default()
	}
	if interval <= 0 {
		interval = 15 * time.Minute
	}
	return &Scheduler{
		feeds:    feeds,
		fetch:    fetch,
		ingest:   ingest,
		store:    st,
		log:      log,
		interval: interval,
		now:      func() int64 { return time.Now().UnixMilli() },
		seen:     make(map[string]string),
	}
}

// RunOnce performs a single ingest pass: fetch each feed, parse, sign and push.
// A failing feed is logged and skipped (one bad upstream never blocks the
// others). It returns the number of events applied to the store this pass.
func (s *Scheduler) RunOnce(ctx context.Context) (int, error) {
	nowMs := s.now()
	var allRecords []AlertRecord
	for _, f := range s.feeds {
		raw, err := s.fetch.Fetch(ctx, f.URL())
		if err != nil {
			s.log.Warn("feed fetch failed", "source", f.Source(), "err", err)
			continue
		}
		recs, perr := f.Parse(raw)
		if perr != nil {
			s.log.Warn("feed parse failed", "source", f.Source(), "err", perr)
			continue
		}
		s.log.Info("feed parsed", "source", f.Source(), "records", len(recs))
		allRecords = append(allRecords, recs...)
	}
	if len(allRecords) == 0 {
		return 0, nil
	}

	// Only sign+push alerts that are new or whose content changed since a prior
	// pass, so an unchanged upstream does not mint a fresh higher-lamport event
	// every interval. Fingerprint by the alert's stable id + meaningful fields.
	s.mu.Lock()
	changed := allRecords[:0:0]
	for _, rec := range allRecords {
		if rec.NativeID == "" {
			continue
		}
		id := AlertID(rec.Source, rec.NativeID)
		fp := fingerprint(rec)
		if prev, ok := s.seen[id]; ok && prev == fp {
			continue
		}
		s.seen[id] = fp
		changed = append(changed, rec)
	}
	s.mu.Unlock()

	if len(changed) == 0 {
		s.log.Info("feed ingest pass complete: nothing changed")
		return 0, nil
	}

	start := s.lamport.Load()
	evs, err := s.ingest.SignAll(changed, start, nowMs)
	if err != nil {
		return 0, err
	}
	// Advance the feed key's lamport past the events we just produced.
	if n := uint64(len(evs)); n > 0 {
		s.lamport.Store(start + n)
	}

	applied, rejected, err := s.store.Push(ctx, evs)
	if err != nil {
		return 0, err
	}
	if len(rejected) > 0 {
		// Our own events should never be rejected; surface it loudly.
		s.log.Error("feed events rejected by store", "rejected", len(rejected))
	}
	s.log.Info("feed ingest pass complete", "applied", len(applied), "events", len(evs))
	return len(applied), nil
}

// fingerprint is a stable digest of a record's meaningful content, used to
// detect whether an alert changed since a prior pass (expiry is excluded so a
// rolling default-TTL does not look like a change).
func fingerprint(rec AlertRecord) string {
	h := sha256.Sum256([]byte(fmt.Sprintf("%s|%s|%s|%s|%.5f|%.5f",
		rec.Source, rec.Title, rec.Detail, rec.Severity, rec.Lat, rec.Lon)))
	return hex.EncodeToString(h[:])
}

// Run loops RunOnce on the configured interval until ctx is cancelled. It runs
// an immediate first pass so a freshly-started worker populates alerts without
// waiting a full interval.
func (s *Scheduler) Run(ctx context.Context) error {
	if _, err := s.RunOnce(ctx); err != nil && ctx.Err() == nil {
		s.log.Error("feed ingest pass failed", "err", err)
	}
	t := time.NewTicker(s.interval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-t.C:
			if _, err := s.RunOnce(ctx); err != nil && ctx.Err() == nil {
				s.log.Error("feed ingest pass failed", "err", err)
			}
		}
	}
}
