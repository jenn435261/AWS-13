// Command worker is the Resilience Network cloud worker service.
//
// It is a SEPARATE process from the api service (microservice isolation): it
// consumes serialized SignedEvents from a queue, re-verifies them, and
// materializes accepted events into the Store. It shares only the events, store
// and queue packages with the api service.
//
// Configuration (environment):
//
//	RESILIENCE_PG_DSN Postgres DSN; when set, materialize into PostgresStore
//	                  (Migrate on boot). When unset, uses the in-memory store.
//	RESILIENCE_SQS_URL SQS queue URL; when set, consume from SQS. When unset,
//	                   uses an in-memory queue (local run / smoke test) and
//	                   exits once drained unless RESILIENCE_WORKER_FOREVER=1.
//
// The service shuts down gracefully on SIGINT/SIGTERM.
package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	cloudaws "github.com/resilience-network/aws13/cloud/internal/aws"
	"github.com/resilience-network/aws13/cloud/internal/queue"
	"github.com/resilience-network/aws13/cloud/internal/store"
	"github.com/resilience-network/aws13/cloud/internal/worker"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	// Store selection (shared with api via the store package only).
	var st store.Store
	if dsn := os.Getenv("RESILIENCE_PG_DSN"); dsn != "" {
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
		log.Info("worker using postgres store")
	} else {
		st = store.NewMemStore()
		log.Info("worker using in-memory store")
	}

	// Queue selection.
	var q queue.Queue
	if url := os.Getenv("RESILIENCE_SQS_URL"); url != "" {
		sqsQ, err := cloudaws.NewSQSQueue(ctx, url)
		if err != nil {
			log.Error("init sqs", "err", err)
			os.Exit(1)
		}
		q = sqsQ
		log.Info("worker consuming from SQS", "url", url)
	} else {
		q = queue.NewMemQueue()
		log.Info("worker using in-memory queue (local)")
	}

	w := worker.New(q, st, log)
	if err := w.Run(ctx); err != nil && ctx.Err() == nil {
		log.Error("worker exited", "err", err)
		os.Exit(1)
	}
	log.Info("worker stopped")
}
