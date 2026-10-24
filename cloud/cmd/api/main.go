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

	if dir := getenv("WEB_DIR", ""); dir != "" {
		opts = append(opts, api.WithWebDir(dir))
		log.Info("serving web app", "dir", dir)
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
