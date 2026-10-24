// Command feedworker ingests public emergency/hazard feeds into cloud-signed
// EMERGENCY_ALERT events marked source=official_feed.
//
// It is a SEPARATE process from the api and (queue) worker services: it fetches
// NWS/NOAA CAP, USGS earthquakes, NIFC/FIRMS wildfire, FEMA OpenFEMA and GDACS,
// maps each record to an EmergencyAlertBody, signs it with the cloud-service
// feed key, and pushes it to the Store (verify-before-store applies).
//
// Configuration (environment):
//
//	RESILIENCE_PG_DSN       Postgres DSN; when set, materialize into
//	                        PostgresStore (Migrate on boot). When unset, uses the
//	                        in-memory store (local smoke test only).
//	FEED_SIGNING_KEY        hex-encoded Ed25519 private key (64 bytes) or seed
//	                        (32 bytes) for the cloud feed identity. REQUIRED: the
//	                        worker refuses to run without it (it must never sign
//	                        with an ephemeral key clients do not trust).
//	FEED_INGEST_INTERVAL    Go duration between passes (default 15m).
//	FEED_TTL                Go duration applied to feed records with no upstream
//	                        expiry (default 6h).
//	FEED_RUN_ONCE=1         run a single pass and exit (for Heroku Scheduler).
//
// Deploy note (Heroku): run this on a schedule with the Scheduler add-on, or as
// a worker dyno. The exact commands are in docs/DECISIONS.md (FEAT-004). The
// FEED_SIGNING_KEY lives ONLY in a Heroku config var, never in git.
package main

import (
	"context"
	"crypto/ed25519"
	"encoding/hex"
	"errors"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/resilience-network/aws13/cloud/internal/feeds"
	"github.com/resilience-network/aws13/cloud/internal/store"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	key, err := loadFeedKey(os.Getenv("FEED_SIGNING_KEY"))
	if err != nil {
		log.Error("feed signing key", "err", err)
		os.Exit(1)
	}

	var st store.Store
	if dsn := os.Getenv("RESILIENCE_PG_DSN"); dsn != "" {
		pg, perr := store.OpenPostgres(dsn)
		if perr != nil {
			log.Error("open postgres", "err", perr)
			os.Exit(1)
		}
		defer pg.Close()
		if merr := pg.Migrate(ctx); merr != nil {
			log.Error("migrate", "err", merr)
			os.Exit(1)
		}
		st = pg
		log.Info("feedworker using postgres store")
	} else {
		st = store.NewMemStore()
		log.Info("feedworker using in-memory store (local only)")
	}

	ttl := parseDuration(os.Getenv("FEED_TTL"), 6*time.Hour)
	interval := parseDuration(os.Getenv("FEED_INGEST_INTERVAL"), 15*time.Minute)
	ingest := feeds.NewIngestor(key, ttl.Milliseconds())
	log.Info("feed ingestor ready", "feed_pubkey", ingest.PublicKeyHex())

	reg := feeds.Registry()
	list := []feeds.Feed{
		reg[feeds.SourceNWS], reg[feeds.SourceUSGS], reg[feeds.SourceWildfire],
		reg[feeds.SourceFEMA], reg[feeds.SourceGDACS],
	}
	sched := feeds.NewScheduler(list, feeds.NewHTTPFetcher(), ingest, st, log, interval)

	if os.Getenv("FEED_RUN_ONCE") == "1" {
		n, rerr := sched.RunOnce(ctx)
		if rerr != nil {
			log.Error("single ingest pass failed", "err", rerr)
			os.Exit(1)
		}
		log.Info("single ingest pass complete", "applied", n)
		return
	}

	if rerr := sched.Run(ctx); rerr != nil && ctx.Err() == nil {
		log.Error("feedworker exited", "err", rerr)
		os.Exit(1)
	}
	log.Info("feedworker stopped")
}

// loadFeedKey parses a hex Ed25519 private key (64 bytes) or seed (32 bytes).
func loadFeedKey(hexKey string) (ed25519.PrivateKey, error) {
	if hexKey == "" {
		return nil, errors.New("FEED_SIGNING_KEY is required (hex ed25519 private key or seed)")
	}
	raw, err := hex.DecodeString(hexKey)
	if err != nil {
		return nil, errors.New("FEED_SIGNING_KEY must be hex")
	}
	switch len(raw) {
	case ed25519.PrivateKeySize:
		return ed25519.PrivateKey(raw), nil
	case ed25519.SeedSize:
		return ed25519.NewKeyFromSeed(raw), nil
	default:
		return nil, errors.New("FEED_SIGNING_KEY must be 32-byte seed or 64-byte private key (hex)")
	}
}

func parseDuration(s string, def time.Duration) time.Duration {
	if s == "" {
		return def
	}
	d, err := time.ParseDuration(s)
	if err != nil || d <= 0 {
		return def
	}
	return d
}
