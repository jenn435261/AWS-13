// Package worker implements the separate worker service's core loop: it
// consumes serialized SignedEvents from a queue.Queue, RE-VERIFIES each one
// (never trusting that an upstream already did), materializes accepted events
// into the Store, and deletes successfully processed messages from the queue.
//
// The worker depends only on the shared events, store and queue packages — it
// does NOT import the api service internals, so the two processes stay
// decoupled (one failing service cannot take down the other).
package worker

import (
	"context"
	"log/slog"
	"time"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/events"
	"github.com/resilience-network/aws13/cloud/internal/queue"
	"github.com/resilience-network/aws13/cloud/internal/store"
	"google.golang.org/protobuf/proto"
)

// Worker consumes events from a queue and materializes them into a store.
type Worker struct {
	q     queue.Queue
	store store.Store
	log   *slog.Logger
	// PollInterval is the sleep between empty receives (for queues that do not
	// long-poll). Default 1s.
	PollInterval time.Duration
}

// New builds a Worker.
func New(q queue.Queue, st store.Store, log *slog.Logger) *Worker {
	if log == nil {
		log = slog.Default()
	}
	return &Worker{q: q, store: st, log: log, PollInterval: time.Second}
}

// Run consumes until ctx is cancelled. It returns ctx.Err() on cancellation.
func (w *Worker) Run(ctx context.Context) error {
	w.log.Info("worker started")
	for {
		select {
		case <-ctx.Done():
			w.log.Info("worker stopping", "reason", ctx.Err())
			return ctx.Err()
		default:
		}

		msgs, err := w.q.Receive(ctx)
		if err != nil {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			w.log.Error("receive failed", "err", err)
			if !sleep(ctx, w.PollInterval) {
				return ctx.Err()
			}
			continue
		}
		if len(msgs) == 0 {
			if !sleep(ctx, w.PollInterval) {
				return ctx.Err()
			}
			continue
		}

		var done []string
		for _, m := range msgs {
			if w.processOne(ctx, m.Body) {
				done = append(done, m.Handle)
			}
		}
		if len(done) > 0 {
			if derr := w.q.Delete(ctx, done...); derr != nil {
				w.log.Error("delete failed", "err", derr)
			}
		}
	}
}

// ProcessBatch verifies and stores a batch of raw event payloads, returning the
// handles of messages that were fully processed (so they may be deleted). It is
// exported for testing the materialization path without the loop.
func (w *Worker) ProcessBatch(ctx context.Context, msgs []queue.Message) []string {
	var done []string
	for _, m := range msgs {
		if w.processOne(ctx, m.Body) {
			done = append(done, m.Handle)
		}
	}
	return done
}

// processOne decodes a single raw SignedEvent, re-verifies it, and stores it.
// Returns true if the message was handled (stored or safely discarded) and can
// be deleted. Malformed payloads and events that fail verification are
// discarded (returning true) so they do not clog the queue; a store error
// returns false so the message is retried.
func (w *Worker) processOne(ctx context.Context, body []byte) bool {
	ev := &resiliencev1.SignedEvent{}
	if err := proto.Unmarshal(body, ev); err != nil {
		w.log.Warn("drop undecodable message", "err", err)
		return true
	}
	if ok, reason := events.VerifyEvent(ev); !ok {
		w.log.Warn("drop invalid event", "reason", reason)
		return true
	}
	applied, rejected, err := w.store.Push(ctx, []*resiliencev1.SignedEvent{ev})
	if err != nil {
		w.log.Error("store push failed, will retry", "err", err)
		return false
	}
	w.log.Debug("materialized", "applied", len(applied), "rejected", len(rejected))
	return true
}

func sleep(ctx context.Context, d time.Duration) bool {
	if d <= 0 {
		return ctx.Err() == nil
	}
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return false
	case <-t.C:
		return true
	}
}
