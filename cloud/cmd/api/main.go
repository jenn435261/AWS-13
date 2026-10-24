// Command api is the Resilience Network cloud API service.
//
// It serves the slim HTTP event-store API (POST /v1/events, /v1/events/pull,
// /healthz, /readyz). Configuration is read from the environment:
//
//	PORT              listen port (default 8080)
//	RESILIENCE_PG_DSN Postgres DSN; when set, uses PostgresStore (and runs
//	                  Migrate on boot). When unset, uses the in-memory store so
//	                  the service runs with zero AWS/DB dependencies locally.
//
// The service shuts down gracefully on SIGINT/SIGTERM.
package main

import (
	"context"
	"crypto/ed25519"
	"encoding/hex"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/resilience-network/aws13/cloud/internal/ai"
	"github.com/resilience-network/aws13/cloud/internal/api"
	"github.com/resilience-network/aws13/cloud/internal/org"
	"github.com/resilience-network/aws13/cloud/internal/packages"
	"github.com/resilience-network/aws13/cloud/internal/store"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	port := getenv("PORT", "8080")
	dsn := os.Getenv("RESILIENCE_PG_DSN")

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	var (
		st    store.Store
		ready func(ctx context.Context) error
	)
	if dsn == "" {
		log.Info("no RESILIENCE_PG_DSN set; using in-memory store (zero external deps)")
		st = store.NewMemStore()
	} else {
		pg, err := store.OpenPostgres(dsn)
		if err != nil {
			log.Error("open postgres", "err", err)
			os.Exit(1)
		}
		defer pg.Close()
		if merr := pg.Migrate(ctx); merr != nil {
			log.Error("migrate", "err", merr)
			os.Exit(1)
		}
		st = pg
		ready = pg.Ping
		log.Info("using postgres store")
	}

	opts := []api.Option{api.WithReadiness(ready)}
	// Enable the online AI path only when BEDROCK_MODEL_ID is explicitly set.
	// Otherwise the API serves the deterministic rules path (degraded:true),
	// so the core system works without AI (spec §67).
	if _, configured := ai.ModelIDFromEnv(); configured {
		assistant, err := ai.NewBedrockAssistant(ctx)
		if err != nil {
			log.Warn("bedrock assistant unavailable; AI endpoints will use rules fallback", "err", err)
		} else {
			opts = append(opts, api.WithOnlineAssistant(assistant))
			log.Info("bedrock AI assistant enabled", "model_id", assistant.ModelID())
		}
	} else {
		log.Info("no BEDROCK_MODEL_ID set; AI endpoints use deterministic rules (degraded)")
	}

	// Org/first-responder integration (aggregate needs API + trusted-org alert
	// tagging). Gated by env so it is off unless explicitly configured.
	if tokens := getenv("ORG_API_TOKENS", ""); tokens != "" {
		list := splitCSV(tokens)
		opts = append(opts, api.WithOrgTokens(list))
		log.Info("org needs API enabled", "tokens", len(list))
	}
	if pubkeys := getenv("ORG_TRUSTED_PUBKEYS", ""); pubkeys != "" {
		trusted := org.ParseTrustedOrgs(pubkeys)
		opts = append(opts, api.WithTrustedOrgs(trusted))
		log.Info("trusted org keys loaded", "count", trusted.Len())
	}

	if keys := getenv("CLIENT_API_KEYS", ""); keys != "" {
		opts = append(opts, api.WithClientTokens(splitCSV(keys)))
		log.Info("client api key gate enabled")
	}

	// The cloud feed signing key's PUBLIC hex, so /v1/alerts serves feed alerts
	// and /app-config.json advertises it as the trusted feed root. This is the
	// public half only; the private FEED_SIGNING_KEY lives with the feedworker.
	if pub := getenv("FEED_PUBKEY", ""); pub != "" {
		if raw, derr := hex.DecodeString(strings.TrimSpace(pub)); derr == nil && len(raw) == ed25519.PublicKeySize {
			opts = append(opts, api.WithFeedPubkey(raw))
			log.Info("feed pubkey configured (official-feed alerts enabled)")
		} else {
			log.Warn("FEED_PUBKEY set but not a 32-byte hex ed25519 key; ignoring")
		}
	}

	if dir := getenv("WEB_DIR", ""); dir != "" {
		opts = append(opts, api.WithWebDir(dir))
		log.Info("serving web app", "dir", dir)
	}

	// Cloud map/guidance packs (PMTiles) served with Range + a cloud-signed
	// manifest. The signing key lives ONLY in env, never in git.
	if dir := getenv("CLOUD_PACKAGES_DIR", ""); dir != "" {
		pkg := packages.New(packages.Config{PackDir: dir})
		if keyHex := getenv("CLOUD_PACKAGES_SIGNING_KEY", ""); keyHex != "" {
			if key, perr := parseEd25519Key(keyHex); perr == nil {
				pkg.WithSigningKey(key)
				log.Info("cloud packages manifest signing enabled", "pubkey",
					hex.EncodeToString(key.Public().(ed25519.PublicKey)))
			} else {
				log.Warn("CLOUD_PACKAGES_SIGNING_KEY invalid; manifest will be unavailable", "err", perr)
			}
		} else {
			log.Warn("CLOUD_PACKAGES_DIR set without CLOUD_PACKAGES_SIGNING_KEY; manifest unavailable (503)")
		}
		opts = append(opts, api.WithPackages(pkg))
		log.Info("serving cloud packages", "dir", dir)
	}

	srv := api.NewServer(st, opts...)
	httpSrv := &http.Server{
		Addr:              ":" + port,
		Handler:           srv.Handler(),
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Info("api listening", "addr", httpSrv.Addr)
		if err := httpSrv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Error("listen", "err", err)
			stop()
		}
	}()

	<-ctx.Done()
	log.Info("shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := httpSrv.Shutdown(shutdownCtx); err != nil {
		log.Error("graceful shutdown failed", "err", err)
		os.Exit(1)
	}
	log.Info("stopped")
}

// parseEd25519Key accepts a hex ed25519 private key (64 bytes) or seed (32).
func parseEd25519Key(hexKey string) (ed25519.PrivateKey, error) {
	raw, err := hex.DecodeString(strings.TrimSpace(hexKey))
	if err != nil {
		return nil, errors.New("key must be hex")
	}
	switch len(raw) {
	case ed25519.PrivateKeySize:
		return ed25519.PrivateKey(raw), nil
	case ed25519.SeedSize:
		return ed25519.NewKeyFromSeed(raw), nil
	default:
		return nil, errors.New("key must be 32-byte seed or 64-byte private key")
	}
}

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// splitCSV splits a comma-separated env value into trimmed, non-empty parts.
func splitCSV(s string) []string {
	var out []string
	for _, p := range strings.Split(s, ",") {
		if t := strings.TrimSpace(p); t != "" {
			out = append(out, t)
		}
	}
	return out
}
