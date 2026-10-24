# Overnight Engineering Run — Resilience Network

Branch: `kiro/overnight` (off `feature/provider-map-supplies`). Commit small and often; do not push/merge/force-push.

## Final report

_Placeholder — filled in at the end of the run once items A–G are complete. Will summarize what shipped, what was skipped (and why), the final verification state, and anything left for the human to do (e.g. Heroku deploy, live-site click-through)._

## Running log

### 2026-10-24 — FEAT-001: baseline + toolchain confirmed

Confirmed a green baseline and seeded this log plus `docs/DECISIONS.md`.

**Reusable shell env block** — prepend to EVERY shell command that runs flutter/dart/go/buf (the sandbox resets `/tmp` and env vars between calls; only `/projects/sandbox` persists):

```sh
export HOME=/projects/sandbox/.toolchain/home
export PUB_CACHE=/projects/sandbox/.toolchain/pub-cache
export GIT_CONFIG_GLOBAL=$HOME/.gitconfig
export GOTOOLCHAIN=auto
export GOBIN=/projects/sandbox/.toolchain/gobin
export PATH=/projects/sandbox/.toolchain/gobin:/projects/sandbox/.toolchain/pub-cache/bin:/projects/sandbox/.toolchain/flutter/bin/cache/dart-sdk/bin:/projects/sandbox/.toolchain/flutter/bin:$PATH
```

**Verified toolchain** (already installed under `/projects/sandbox/.toolchain` by the planner — do NOT reinstall or change versions):

- Flutter 3.47.8 / Dart 3.13.7. This exact Flutter is required: `app/pubspec.yaml` needs Dart `^3.11.3`, and earlier stable Flutters fail to resolve `meta`/`sqlite3`/`hooks`. Do NOT downgrade Flutter.
- Go 1.26 auto-downloads via `GOTOOLCHAIN=auto` (host Go is 1.25.1; the `go.mod` files require `>=1.26.0`).
- `buf`, `protoc-gen-go` v1.36.12, and `protoc-gen-dart` are installed in the toolchain and on `PATH` via the block above.
- Chrome for Testing 151 is at `/usr/local/bin/chrome` for later browser click-through features.

**Baseline verification results (all green):**

- `cd app && flutter analyze` → `No issues found!`
  - Note: with the OS sandbox, the analysis server emits cosmetic `OS Error: Too many open files, errno = 24` lines. Running `ulimit -n 8192` before `flutter analyze`/`flutter test` makes the command exit 0; the analysis result itself is clean regardless.
- `cd app && flutter test $(ls test/*.dart | grep -v screenshots_test.dart)` → **119 tests, all passed.**
  - `test/screenshots_test.dart` is ALWAYS excluded: it hard-codes a sandbox font path and fails in this environment.
- `cd cloud && go vet ./... && go test ./...` → all `ok`.
- `cd node && go vet ./... && go test ./...` → all `ok`.
- `cd proto && buf generate` then `git status --short app/lib/gen cloud/gen node/gen` → **zero diff** (clean round-trip with protoc-gen-go v1.36.12 + protoc-gen-dart).
  - `buf.gen.yaml` emits Dart to `app/lib/gen` and Go to `cloud/gen`; `node/gen` is a vendored copy of `cloud/gen` (`event.pb.go`/`sync.pb.go` are byte-identical). If a real proto change lands, after `buf generate` copy `cloud/gen/resilience/v1/*.go` over `node/gen/resilience/v1/*.go`.

**Platform limits (recorded for the human; these steps are skipped by the agent):**

- **Heroku CLI is NOT installed/authenticated.** All deploy steps and the live-site (`resilience.chrisccluk.live`) click-through are SKIPPED. The exact Heroku commands are documented for the human but MUST NOT be run by the agent. See `cloud/DEPLOY_HEROKU.md` for the full procedure; the shape is:

  ```sh
  # Human-only — do NOT run in the sandbox.
  heroku login
  heroku git:remote -a <app-name>
  heroku config:set RESILIENCE_PG_DSN=... CLOUD_API_KEY=... AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=...
  git push heroku kiro/overnight:main
  heroku logs --tail
  ```

- **`flutter build web --wasm` is expected to FAIL** (plugins). Use the default JS build: `flutter build web --release`.
- **`infra/` and `cdk` are OFF LIMITS.** Never touch `infra/` or run `cdk`.
- Long-running servers for click-through must be started and used within a SINGLE shell call (background processes do not persist between tool calls); `/projects/sandbox` persists, `/tmp` does not.

### 2026-10-24 — FEAT-002 (Item A): app-side cloud + node sync client

Built the app's sync client and wired it end to end.

**What shipped:**

- `app/lib/sync/cloud_sync.dart` — `CloudSync`, a one-shot pull+push client parameterized by `SyncEndpointKind` (cloud `/v1/events` + `/v1/events/pull`; node `/node/v1/push` + `/node/v1/pull`). It builds a `PullEventsRequest` from `EventStore.highWaterByAuthor()`, applies the returned `EventBatch` through `EventStore.applyAll` (the single verify-then-store path), then pushes our own events above a stored push high-water as a `PushEventsRequest`. JSON on the wire; sends `X-Api-Key` from `cloudApiKeyProvider` when non-empty. A `SyncHttp` seam (default `HttpSyncHttp` with a 10s timeout) lets tests inject a fake transport. Returns an honest `SyncOutcome` (pushed/applied/rejected/pending/error); never throws.
- `app/lib/sync/sync_providers.dart` — hand-written Riverpod layer: `syncStatusProvider` (`SyncStatus`: lastSyncedMs / pendingCount / lastError / syncing), `cloudSyncProvider`, `nodeSyncProvider` (null ⇒ no-op when no active node), `syncCursorsProvider` (KeyValue `sync:` namespace), `syncHttpProvider` (overridable), and `SyncCoordinator` + `SyncLifecycleObserver`. The coordinator runs cloud+node rounds, bumps `worldRevisionProvider` when new events applied, and triggers on start, on `AppLifecycleState.resumed`, after every local write, and on a 30s visible-only periodic timer, with 1s→2m exponential backoff on failure.
- `app/lib/main.dart` — wraps `AppShell` in `SyncLifecycleObserver`.
- `app/lib/ui/screens/network_status_screen.dart` — a real "Sync" row driven by live `SyncStatus`: "Last synced <relative> · N pending" with a truthful error line when the last round failed; the Refresh button now also kicks a sync. Text ≥16px.
- l10n — added `sync_status`, `sync_never`, `sync_pending`, `last_synced`, `sync_error`, `time_just_now`, `time_minutes_ago`, `time_hours_ago`, `time_days_ago` to EN+ES (`strings_new.dart`), FR (`strings_fr.dart`) and ZH (`strings_zh.dart`).
- `cloud/DEPLOY_HEROKU.md` — documented (did NOT run) the durable-storage provisioning: `heroku addons:create heroku-postgresql:essential-0 -a resilience-api-chris` then `heroku config:set RESILIENCE_PG_DSN=$(heroku config:get DATABASE_URL -a resilience-api-chris) -a resilience-api-chris`.

**Tests added:**

- `app/test/cloud_sync_test.dart` (8 tests) — fake-transport (a second `EventStore`-backed server, mirroring `sync_engine_test.dart`): proves push, pull-with-apply, the forged/tampered-event abuse case (rejected and never stored), the `X-Api-Key` header, pending-count tracking, idempotence, and honest error handling for a down endpoint and a non-200 response.
- `cloud/internal/api/server_test.go` — `TestTwoProfileSyncThroughCloud` (the two-profile substitute, see below).

**Verification (all green):**

- `cd app && flutter analyze` → `No issues found!` (with `ulimit -n 8192`).
- `cd app && flutter test $(ls test/*.dart | grep -v screenshots_test.dart)` → **127 passed** (119 baseline + 8 new).
- `cd cloud && go vet ./... && go test ./...` → all `ok` (incl. the new two-profile test).
- `cd node && go vet ./... && go test ./...` → all `ok`.

**Two-profile scenario — what ran vs. what was substituted (honest record):**

- NOT run: the full browser two-profile click-through (build web + puppeteer-core + two Chrome contexts against a locally-run cloud+node+served web build). The combined one-shell-call orchestration (release web build, three background servers, puppeteer npm install, two profiles, screenshots, teardown) was deemed too fragile/slow for the single-shell-invocation constraint this round.
- Ran instead: a Go-level two-client integration test, `TestTwoProfileSyncThroughCloud`, against a **real local cloud API** (`httptest.NewServer`). Two distinct Ed25519 identities model profiles A and B: A publishes a help request + supply + emergency alert + identity certificate and pushes them via `POST /v1/events`; B pulls via `POST /v1/events/pull` from an empty watermark and receives all four **byte-identical** (so verified/community provenance in the body survives), then a re-pull from the new watermark returns zero (idempotence). This exercises the exact cloud endpoints and request/response types `CloudSync` uses.
