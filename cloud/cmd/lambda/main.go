// Command lambda is the AWS Lambda entrypoint for the Resilience Network cloud
// API. It adapts the existing internal/api HTTP handler to the Lambda runtime
// using the aws-lambda-go-api-proxy httpadapter, so the exact same routes
// (POST /v1/events, /v1/events/pull, /v1/ai/*, /v1/org/needs, /healthz) are
// served over a Lambda Function URL without rewriting any handler logic.
//
// It mirrors cmd/api/main.go's wiring: an in-memory store by default (zero
// external deps), optionally Postgres when RESILIENCE_PG_DSN is set, and the
// Bedrock online AI path when BEDROCK_MODEL_ID is configured (falling back to
// the deterministic rules path otherwise). The binary is cross-compiled to a
// `bootstrap` executable for the provided.al2023 runtime (see `make
// lambda-build`).
package main

import (
	"context"
	"log/slog"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/awslabs/aws-lambda-go-api-proxy/httpadapter"

	"github.com/resilience-network/aws13/cloud/internal/ai"
	"github.com/resilience-network/aws13/cloud/internal/api"
	"github.com/resilience-network/aws13/cloud/internal/store"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	// Lambda init runs once per cold start; build the handler here so warm
	// invocations reuse the same store and AI assistant.
	ctx := context.Background()
	dsn := os.Getenv("RESILIENCE_PG_DSN")

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
		if merr := pg.Migrate(ctx); merr != nil {
			log.Error("migrate", "err", merr)
			os.Exit(1)
		}
		st = pg
		ready = pg.Ping
		log.Info("using postgres store")
	}

	opts := []api.Option{api.WithReadiness(ready)}
	// Enable the online AI path only when BEDROCK_MODEL_ID is explicitly set,
	// matching cmd/api/main.go. Otherwise AI endpoints serve the deterministic
	// rules path (degraded:true).
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

	srv := api.NewServer(st, opts...)

	// Wrap the same http.Handler the API server builds. httpadapter translates
	// the Lambda Function URL (API Gateway v2 / Function URL) payload into a
	// standard *http.Request and back, so no route logic changes.
	adapter := httpadapter.NewV2(srv.Handler())

	log.Info("lambda handler ready")
	lambda.Start(adapter.ProxyWithContext)
}
