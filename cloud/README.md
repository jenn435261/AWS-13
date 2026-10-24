# Resilience Network — Cloud backend

An AWS-native, authoritative event store for the Resilience Network. It ingests
signed events, **verifies every event (Ed25519 signature + BLAKE2b-256 content
hash) before persisting**, and serves sync. The cloud is an optional, large,
well-connected synchronized view; phones/nodes remain authoritative locally.
But the server is authoritative for *what it accepts*: it never trusts
client-supplied derived state (event id, signature) without recomputing and
re-verifying.

The backend is deliberately **slim** and ships as **two decoupled
microservices** so one failing service cannot take the other down:

- `cmd/api` — the HTTP event-store API (push/pull/health).
- `cmd/worker` — a separate consumer that re-verifies and materializes events
  from a queue (SQS in AWS, in-memory locally).

## Layout

```
cloud/
  cmd/api/            API service entrypoint
  cmd/worker/         Worker service entrypoint (separate process)
  internal/events/    VerifyEvent + canonical/preimage/hash helpers
  internal/store/     Store interface, MemStore, PostgresStore (PostGIS)
  internal/api/       net/http API (protobuf + JSON content negotiation)
  internal/queue/     Queue interface + MemQueue
  internal/aws/       AWS adapters: S3, SQS (Queue impl), IoT Core publish
  gen/resilience/v1/  generated protobuf (DO NOT EDIT)
```

## Event verification (must match the Dart client)

Identity and authenticity are derived from the deterministic protobuf encoding
of the `EventHeader` concatenated with the raw body bytes:

- hash preimage      = `canonicalHeader(event_id CLEARED) || body`
- signature preimage = `canonicalHeader(event_id SET)     || body`
- `event_id`  = `BLAKE2b-256(hash preimage)` (32 bytes)
- `signature` = `Ed25519(author_pubkey).sign(signature preimage)` (64 bytes)

Canonical header bytes use `proto.MarshalOptions{Deterministic: true}` over a
clone of the header, matching protobuf-dart's `writeToBuffer()` (ascending tag
order, single canonical wire encoding, unknown fields stripped). See
`internal/events/verify.go` and the Dart `app/lib/core/canonical.dart` /
`event_factory.dart`.

## Run locally (zero AWS/DB deps)

```sh
source /projects/sandbox/.toolchain/env.sh   # Go toolchain + PATH
cd cloud
go run ./cmd/api
# in another shell:
curl -s localhost:8080/healthz    # {"status":"ok"}
curl -s localhost:8080/readyz     # {"status":"ready"}
```

With no `RESILIENCE_PG_DSN`, the API uses the in-memory store.

### Push / pull (JSON)

```sh
curl -s -X POST localhost:8080/v1/events \
  -H 'Content-Type: application/json' -H 'Accept: application/json' \
  -d '{"events":[ ...PushEventsRequest JSON... ]}'

curl -s -X POST localhost:8080/v1/events/pull \
  -H 'Content-Type: application/json' -H 'Accept: application/json' \
  -d '{"from":[{"authorPubkey":"<base64>","fromLamport":"0"}]}'
```

Both endpoints also accept and emit `application/x-protobuf` (default when no
JSON content type / accept header is given).

## Run with Postgres

```sh
export RESILIENCE_PG_DSN='postgres://user:pass@localhost:5432/resilience?sslmode=disable'
go run ./cmd/api     # runs Migrate() on boot (creates PostGIS extension + schema)
```

The schema stores each event's raw deterministic protobuf plus projected header
columns and an optional `geog geography(Point,4326)` column (with a GIST index)
populated from the event's `GeoPoint`, enabling later "resources within N km"
queries.

## Run the worker

```sh
# local: in-memory queue + in-memory store
go run ./cmd/worker

# AWS: consume from SQS, materialize into Postgres
export RESILIENCE_PG_DSN='postgres://...'
export RESILIENCE_SQS_URL='https://sqs.us-east-1.amazonaws.com/123456789012/events'
go run ./cmd/worker
```

## Environment variables

| Var                 | Service      | Meaning                                                        |
|---------------------|--------------|----------------------------------------------------------------|
| `PORT`              | api          | Listen port (default `8080`).                                  |
| `RESILIENCE_PG_DSN` | api, worker  | Postgres DSN. Unset → in-memory store.                         |
| `RESILIENCE_SQS_URL`| worker       | SQS queue URL. Unset → in-memory queue (local).                |

AWS adapters (`internal/aws`: S3, SQS, IoT Core) use `aws-sdk-go-v2`, sit behind
interfaces, and are inert without valid credentials/endpoints.

## Deploy shape (ECS/Fargate)

Build two images from this module and run them as two independent services:

- **api** service: `go build ./cmd/api`, fronted by an ALB; scales on request
  load; reads from Postgres (RDS) with PostGIS.
- **worker** service: `go build ./cmd/worker`; scales on SQS queue depth;
  consumes, re-verifies, and materializes events.

The worker imports only the shared `events`, `store`, and `queue` packages — not
the api internals — keeping the processes isolated.

## Tests

```sh
source /projects/sandbox/.toolchain/env.sh
cd cloud
go build ./... && go vet ./... && go test ./...
```

Postgres and AWS integration tests skip automatically when their env vars
(`RESILIENCE_PG_DSN`, AWS credentials) are unset.
