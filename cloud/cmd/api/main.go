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
	"syscall"
	"time"

	"github.com/resilience-network/aws13/cloud/internal/api"
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

	srv := api.NewServer(st, api.WithReadiness(ready))
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
