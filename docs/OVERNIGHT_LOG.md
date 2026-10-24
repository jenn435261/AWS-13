# Overnight Engineering Run — Resilience Network

Branch: `kiro/overnight` (off `feature/provider-map-supplies`). Commit small and often; do not push/merge/force-push.

## Final report

### 1. Done vs. not (one paragraph)

All seven planned features (FEAT-001 baseline/docs, and items A–G) shipped on `kiro/overnight` and the codebase is green: `flutter analyze` is clean, **167** Flutter tests pass (`screenshots_test.dart` excluded as always — it has a hard-coded font path), and all cloud+node Go `vet`/`test` pass, with `flutter build web --release` building and `buf generate` round-tripping with no diff. (The count rose from 164 to 167 after the v1-review follow-up added three regression tests; see the Running log.) The app now actually syncs (push/pull to cloud and node, verify-before-store), has working end-to-end secure messaging with photos/audio, opt-in time-boxed location sharing, full provider tooling (verified supplies, alerts + recall, missions + carrier assign/accept, certify, request close/cancel, auto-hide of expired supplies, certificate depth-limit = 2), an offline PMTiles **raster** map from a node with an honest online fallback, AI translate/summarize/dedup surfaced honestly in the UI, cloud **CORS** (so a cross-origin web host can call the API), and a node-served **signed package manifest** (detached Ed25519, SHA-256 per file, HTTP Range-resume) that the app verifies before trusting a download. What was NOT done is deployment and the live-site click-through (**Heroku CLI is not installed/authenticated in this sandbox**) and anything requiring on-device-only capabilities or `infra/` (off limits); interaction-level browser driving of the Flutter UI is not possible headlessly (the semantics tree publishes no aria-labels in this sandbox), so UI behavior is proven by Dart fold/abuse tests + Go endpoint tests + zero-console-error same-origin boots, which is called out per item below.

### 2. Feature state table

| Feature | State | How verified | Evidence (test / screenshot) |
|---|---|---|---|
| A — App-side cloud + node sync client | works | Dart unit/integration tests; Go server push/pull; zero-error boots | `app/test/cloud_sync_test.dart`, `app/test/sync_engine_test.dart`, `cloud/internal/api/server_test.go` `TestTwoProfileSyncThroughCloud`, `.agents/tmp/shots7/profileA_booted.png` |
| B — Secure messaging (text + photo + audio) | works | Dart E2E round-trip incl. tamper abuse cases; Go ciphertext-only assertions; durable store survives restart | `app/test/messaging_e2e_test.dart`, `signal_messaging_test.dart`, `message_flow_test.dart`, `photo_prep_test.dart`, `drift_signal_store_test.dart` |
| C — Location sharing | works | Fold + abuse tests (author-only stop, non-audience cannot decrypt); two-profile geo boot | `app/test/location_share_test.dart`, `location_view_test.dart`, cases in `derived_state_test.dart` |
| D — Provider completeness (+ `HELP_REQUEST_CLOSED` proto, depth-limit=2) | works | Fold + abuse tests (owner-only close, non-owner ignored, verified-only mission create/assign, author-only recall, cert depth 2 vs 3) | `app/test/derived_state_test.dart`, `app/test/mission_chain_test.dart`, `app/test/supply_and_provider_test.dart` |
| E — Offline PMTiles raster map | works (raster only) | Provider returns null on vector/unreachable (no silent blank); web build intact; node Range 206 | `app/test/map_pmtiles_test.dart`; `.agents/tmp/shots7/profileA_map.png` baseline boots |
| F — AI endpoints in the UI (translate/summarize/dedup) | works | Dart tests incl. degraded + offline-fallback paths | `app/test/ai_assist_test.dart` |
| G — Cloud CORS | works | Go preflight test; **real cross-origin browser call** from a different origin succeeded (GET read + preflighted POST with X-Api-Key) | `cloud/internal/api/cors_test.go` `TestCORSPreflight`/`TestCORSHeadersOnActualRequest`; `.agents/tmp/shots7/cross_origin_cors.png` |
| G — Node signed package manifest (checksum + Range-resume) | works | Go sign/verify + Range-resume tests; **browser** verified the detached Ed25519 signature and a resumed two-part Range download whose SHA-256 matched the signed manifest | `node/internal/packages/manifest_test.go` (`TestManifestSignAndVerify`, `TestRangeResumeDownload`, `TestManifestEndpoint503WithoutKey`); `app/test/package_manifest_test.dart` |
| G — App-side checksum verification before trusting a download | works (honest web limits) | Dart verifier tests (ok/untrustedKey/badSignature/malformed, known SHA-256 vector); on-device background download/resume honestly limited on web | `app/test/package_manifest_test.dart` |
| FEAT-005 cancel UI + auto-hide (verify only) | works | Confirmed present, not re-implemented (`_closeRequest`→`HelpRequestClosedBody`; `WorldState.mapResources()`/`ResourceView.isExpired`) | `app/lib/ui/screens/my_posts_screen.dart`, `app/lib/state/derived_state.dart`, `app/test/derived_state_test.dart` |
| Docs honesty (README / KIRO_HANDOFF / SPEC / DECISIONS) | works | Screen-by-screen sweep; "What works today" and status labels updated to match A–G | `README.md`, `docs/KIRO_HANDOFF.md`, `docs/SPEC_PROVIDER_AND_FEATURES.md`, `docs/DECISIONS.md` |

### 3. Not done, and exactly why

- **Heroku deploy + live-site click-through (`resilience.chrisccluk.live`): SKIPPED.** The Heroku CLI is **not installed or authenticated** in this sandbox, so neither the deploy nor the live two-profile click-through could run. Commands for the human (do NOT run in the sandbox):

  ```sh
  heroku login
  heroku git:remote -a resilience-api-chris
  heroku config:set CLIENT_API_KEYS=<key> \
    AWS_REGION=us-east-1 AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_SESSION_TOKEN=... \
    BEDROCK_MODEL_ID=us.anthropic.claude-sonnet-4-5-20250929-v1:0
  # Optional durable store:
  heroku addons:create heroku-postgresql:essential-0   # sets RESILIENCE_PG_DSN
  ./scripts/deploy-heroku.ps1    # builds web, copies into cloud/web, subtree-pushes cloud/
  heroku logs --tail -a resilience-api-chris
  ```
  Full procedure + config vars + custom-domain steps: `cloud/DEPLOY_HEROKU.md`.
- **Interaction-level browser click-through of the Flutter UI: SUBSTITUTED (applies across items A–F).** The headless Flutter semantics tree publishes **no aria-label nodes** in this sandbox, so tapping buttons/fields by accessible name is not possible. UI behavior is therefore proven by the Dart fold/abuse tests + Go endpoint tests + **zero-console-error same-origin boots** (two profiles). For item G the cross-origin point *is* observable at the network layer, so that was driven for real in the browser (see §4 and the table).
- **`flutter build web --wasm`: expected to fail** (plugins) — the JS build `flutter build web --release` is used and passes.
- **`infra/` / CDK: OFF LIMITS** — untouched; not deployable in the event account anyway (`iam:CreateRole` denied).
- **Vector PMTiles rendering: out of scope** — only raster PMTiles are decoded; `maplibre_gl` is not added because it breaks the web build. Vector archives fall back to online OSM (honest, no blank map).
- **Nearby (BLE/Wi-Fi Direct) and LoRa: not exercised** — unavailable in browsers / not set up in this run.
- **On-device background download with a persisted resumable partial file: not on web** — a browser has no filesystem; the node already supports Range-resume and the checksum check runs where the platform can fetch bytes. The UI states this honestly.

### 4. Exact morning test steps for the human

**Local (no deploy needed):**

1. Prepend the env block (top of the running log) and `ulimit -n 8192` to each shell.
2. Re-run the suite: `cd app && flutter analyze` (expect `No issues found!`); `cd app && flutter test $(ls test/*.dart | grep -v screenshots_test.dart)` (expect **164 passing**); `cd cloud && go vet ./... && go test ./...`; `cd node && go vet ./... && go test ./...` (all `ok`).
3. Build + serve the app same-origin through the cloud and run a node with a signed manifest, in ONE shell (pick fresh ports; free them first):
   ```sh
   cd app && flutter build web --release
   # build binaries into /projects/sandbox (not /tmp):
   (cd cloud && go build -o /projects/sandbox/f7/cloudapi ./cmd/api)
   (cd node  && go build -o /projects/sandbox/f7/node ./cmd/resilience-node)
   python3 -c "import os;open('/projects/sandbox/f7/key.hex','w').write(os.urandom(32).hex())"
   mkdir -p /projects/sandbox/f7/maps && head -c 300 /dev/urandom > /projects/sandbox/f7/maps/region.pmtiles
   cp -r app/build/web /projects/sandbox/f7/web
   WEB_DIR=/projects/sandbox/f7/web PORT=8187 CLIENT_API_KEYS=devkey /projects/sandbox/f7/cloudapi &
   /projects/sandbox/f7/node --http-addr :8197 --map-dir /projects/sandbox/f7/maps --packages-signing-key /projects/sandbox/f7/key.hex &
   # also serve the SAME bundle from a DIFFERENT origin to see the CORS win:
   (cd /projects/sandbox/f7/web && python3 -m http.server 8077 &)
   ```
4. **Which two profiles / what to click:** open `http://localhost:8187/` in two separate browser profiles (A and B — the app reads `devkey` from `/app-config.json`). In A, create an "I Need Help" request and (as a provider) an alert; in B, after ~30 s (or tap Refresh in Network Status), the request/alert should appear. **Expected:** B sees A's events; Network Status shows "Last synced … · N pending".
5. **CORS win:** open `http://localhost:8077/` (the different origin) and in the browser console run `await (await fetch('http://localhost:8187/healthz')).text()` → expect `{"status":"ok"}` with no CORS error, and a POST to `http://localhost:8187/v1/events/pull` with header `X-Api-Key: devkey` → expect `200` (the preflight is answered). This is the behavior that was previously blocked.
6. **Signed manifest + checksum:** `curl http://localhost:8197/node/v1/manifest` shows `algorithm:"ed25519"`, a `public_key`, a `signature`, and per-file `sha256`. In the app, More → Offline Downloads → pick the node → Check node: the manifest banner reads **verified** only if you built the app with `--dart-define=PACKAGES_TRUSTED_ROOT=<that public_key>`; the map item then offers **Verify checksum**, which downloads and compares SHA-256 (expect "Checksum verified"). A Range-resume + checksum match is already proven by `node/internal/packages/manifest_test.go` `TestRangeResumeDownload`.
7. (Optional, reproduces the agent's run) `cd /projects/sandbox/.toolchain/ptest && CLOUD_URL=http://localhost:8187 NODE_URL=http://localhost:8197 WEB_ORIGIN=http://localhost:8077 API_KEY=devkey node feat007.mjs` → prints the cross-origin result, manifest-verifies true, resumed-download checksum match true, and "two profiles booted … ZERO console/page errors".

**Live site (once deployed):** after the Heroku deploy in §3, repeat steps 4–6 against `https://resilience.chrisccluk.live` in two browser profiles (it serves the app same-origin with the API and hands the key via `/app-config.json`). Note: an HTTPS page cannot reach a plain-HTTP LAN node (mixed content), so test the node/manifest flow from the native app or give the node HTTPS.

### 5. Known risks + next three things to do

**Risks:**
- Cloud event store is **in-memory** on Heroku unless `RESILIENCE_PG_DSN` is set — events reset on dyno restart.
- UI behavior is covered by unit/fold tests + boots, not by true headless UI driving (sandbox limitation); a real human click-through on the live site is still the highest-value check.
- `PACKAGES_TRUSTED_ROOT` must be provisioned per build for the app to show a manifest as *verified*; without it the UI honestly shows "untrusted/unverified" (it never fakes verification). Node key distribution (how a phone learns the trusted root out of band) is a product decision.
- Cross-origin wildcard CORS is safe only because auth is a header (`X-Api-Key`), never a cookie — do not add cookie/credentialed auth without tightening the origin policy.

**Next three things:**
1. Deploy to Heroku (above), provision Postgres (`RESILIENCE_PG_DSN`), and do the real two-profile live-site click-through.
2. Wire the node's signed-manifest trusted root into the app's provisioning (ship `PACKAGES_TRUSTED_ROOT` for real builds; consider pinning a root via pairing QR) and add a true on-device resumable download with a progress bar on native platforms.
3. Add node discovery (mDNS) and node-side auth for pushes; then exercise nearby (BLE/Wi-Fi Direct) and LoRa transports on real devices.


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

### 2026-10-24 — FEAT-003 (Item B): secure messaging with photos and audio

Made the Messages Direct tab work end to end over the FEAT-002 sync client.

**What shipped:**

- **Durable Signal store (Drift, schema v2).** `app/lib/db/database.dart` gains six `Signal*` tables (identity, one-time prekeys, signed prekeys, sessions, sender keys, trusted remote keys); `schemaVersion` bumped 1→2 with an `onUpgrade` migration; `wipeAll()` clears them. `app/lib/db/signal_dao.dart` (+ regenerated `signal_dao.g.dart`, `database.g.dart`) persists the bytes. `app/lib/messaging/drift_signal_store.dart` — `DriftSignalProtocolStore` write-through wrapper over the vetted libsignal records; `SignalKeys.loadDurableStore` generates+persists device keys on first run and re-hydrates afterward.
- **Prekey publication over the log.** `app/lib/messaging/messaging_service.dart` publishes our bundle as an `EVENT_TYPE_PREKEY_BUNDLE` event and looks up a contact's bundle by folding the log, then runs X3DH — no new endpoint.
- **Encrypted attachments.** `message_payload.dart` (`MessagePayload{kind,text,attachments[]}` + `Attachment{sha256,size,mime,key,thumbnail,…}`), `attachment_cipher.dart` (AES-256-GCM encrypt/decrypt + sha256 verify), `blob_transport.dart` (PUT/GET cloud+node, in-memory fake for tests). `message_flow.dart` gains `sendPayload`/`receivePayload`/`attachBytes`/`fetchAttachment`.
- **Blob endpoints.** `cloud/internal/api/{blobstore.go,server.go}` → `PUT/GET /v1/blobs/{sha256}` (client-key gated, 2 MiB cap, hash-match, rate limit, 7-day purge). `node/internal/syncserver/{blobstore.go,server.go}` → `/node/v1/blobs/{sha256}` (same guards, local Wi-Fi).
- **Media.** `photo_prep.dart` (downscale ≤1600px, ≤8KB thumbnail, **EXIF/GPS strip**), `voice_note.dart` (hold-to-record AAC mono ≤60s + cancel/play/duration), `recorded_bytes*.dart` (platform byte reader). Packages added: `image`, `image_picker`, `record`, `audioplayers` — all web-safe; `flutter build web --release` verified green after adding them.
- **UI.** `app/lib/ui/screens/messages_screen.dart` rewritten: Direct tab lists contacts with messages (newest first), opens a conversation view with delivery states (queued/propagating/delivered/read), and a bottom composer (text ≥16px + photo + hold-to-record voice). Community/Mission stay honest. `messaging_providers.dart` wires the service + blob transport.
- **l10n.** Added `community_not_wired`, `mission_not_wired`, `no_messages_yet`, `photo`, `voice_note`, `attachment_failed`, `cannot_start_chat`, `attach_photo`, `hold_to_record`, `mic_unavailable` to EN+ES (`strings_new.dart`), FR, ZH.

**Tests added:**

- `app/test/messaging_e2e_test.dart` (4) — A→B text+photo+audio round trip through the store+sync seam; delivery-state progression queued→propagating→delivered→read; the blob store holds **only ciphertext**; tampered attachment ciphertext fails hash/auth and is not shown; tampered message ciphertext is rejected and not shown.
- `app/test/drift_signal_store_test.dart` (2) — identity re-hydrates across restart; a session established before "restart" keeps decrypting.
- `app/test/photo_prep_test.dart` (2) — downscale ≤1600px, EXIF stripped from output, thumbnail ≤8KB; non-image returns null.
- `cloud/internal/api/blob_test.go` (6) + `node/internal/syncserver/blob_test.go` (5) — round-trip, hash-mismatch 400, over-cap 413, cloud 401 without key, rate-limit 429, and the **ciphertext-only** privacy assertion (server never holds plaintext or key).

**Verification (all green):**

- `cd app && flutter analyze` → `No issues found!` (with `ulimit -n 8192`).
- `cd app && flutter test $(ls test/*.dart | grep -v screenshots_test.dart)` → **135 passed** (127 + 8 new).
- `cd cloud && go vet ./... && go test ./...` → all `ok`.
- `cd node && go vet ./... && go test ./...` → all `ok`.
- `cd app && flutter build web --release` → `✓ Built build/web` (media packages did not break it).

**Browser click-through — what ran vs. what was substituted (honest record):**

- **Ran:** a single-shell-call orchestration that built the cloud+node binaries, served the release web bundle THROUGH the cloud (same-origin, `WEB_DIR=cloud/web`, `PORT`, `CLIENT_API_KEYS=devkey`) on one port and ran the node on another, then with `puppeteer-core` + `/usr/local/bin/chrome` (headless, `--no-sandbox --disable-dev-shm-usage`, 412px viewport) loaded the app in **two separate browser profiles** (distinct `userDataDir`). Both booted `flutter-view` same-origin reading `/app-config.json`, with **zero console/page errors** (benign favicon/manifest 404s ignored); screenshots saved to `/tmp/feat003_{A,B}_*.png`. In the same call, the cloud+node blob endpoints were exercised **A→B**: A encrypts a sensitive "photo" (with embedded fake GPS text) using a random AES-256-GCM key, PUTs the ciphertext to both cloud and node; the run asserts the servers return **exactly the ciphertext** (never the plaintext or key), that B decrypts it with the key (which never touched a server), that the cloud endpoint is **401 without the devkey**, and that a **hash/content mismatch is 400**.
- **NOT driven through the Flutter UI:** adding contacts by code and composing a photo/voice note by tapping the semantics tree. Reason: a headless browser has **no microphone** (hold-to-record is unobservable) and `image_picker`'s native file dialog cannot be driven headlessly. These paths are instead proven by the Dart A→B text+photo+audio round-trip test (`messaging_e2e_test.dart`) and the Go ciphertext-only assertions above. No browser UI result is claimed that was not actually produced.

### 2026-10-24 — FEAT-004: location sharing (Item C)

Wired location sharing end to end on top of FEAT-002 (sync) and FEAT-003 (Signal E2E). The share/stop/expiry engines (`LocationSharer`, `ActiveShares`) already existed; this feature added the authoritative fold, the UI wiring, the map/list, providers, and the abuse tests.

**What shipped:**

- **Fold (`app/lib/state/derived_state.dart`).** `WorldState._recompute` now folds `EVENT_TYPE_LOCATION_SHARE`/`EVENT_TYPE_LOCATION_STOP` into `WorldState.locationShares` (latest share per `(author, shareId)` by seq→lamport; dropped when `now >= expiresMs` via the injected `clock`, or when the **author** stopped it — stops fold per-author so only the sharer can revoke). New `LocationShareView` carries routing/expiry metadata + the OPAQUE ciphertext; the fold never decrypts or logs a coordinate. New `WorldState.locationSharesVisibleTo(viewerPubkey, channelIds, includePublic)` is the audience filter.
- **Delivery (`app/lib/location/location_coordinator.dart`, `location_providers.dart`).** `LocationCoordinator` reads a one-shot position (`position_service.readPosition`), rounds to ~110 m unless the user picked Exact, encrypts the precise `GeoPoint` per contact over the SAME durable Signal session used for messaging (`MessagingService.outboundSessionFor`), emits a signed `LOCATION_SHARE` per recipient (shared `shareId`) through `EventStore`, and on Stop emits `LOCATION_STOP`. A contact with no published prekey bundle is reported `unreachable` (honest state). `incomingSharesProvider` decrypts shares addressed to this device via `inboundSessionFrom` + `ActiveShares.incomingFor`.
- **UI.** `location_share_screen.dart`: the Share button is **enabled** (was `onPressed:null`), the `location_not_connected` note is **removed**, a contact picker drives the contact audience, and honest toasts cover location denied / service off / timeout (no crash, no infinite spinner). Stop publishes `LOCATION_STOP` (author-wide). `map_screen.dart`: people sharing WITH this device render as a distinct teal `person_pin_circle` (`AppTheme.sharing`) plus an "N sharing" chip that opens a list sheet; a marker disappears when the sharer stops or the share expires (fold recompute). Every write calls `bumpWorld`, which triggers a sync via `SyncLifecycleObserver`.
- **l10n.** New EN/ES keys in `strings_new.dart`, FR in `strings_fr.dart`, ZH in `strings_zh.dart` (completeness test still green).

**Tests added (6; 135 → 141):**

- `app/test/location_share_test.dart` (+4) — WorldState fold A→B: A shares 15m, **B sees it, non-audience C does not** and C's unrelated session cannot decrypt A's ciphertext (no plaintext leak); A stops → the share is gone from the fold; **expiry without a stop** (advance the injected clock past `expiresMs`) removes it; **abuse** — C's forged `LOCATION_STOP` for A's share does nothing (only the sharer can revoke).
- `app/test/location_view_test.dart` (+2) — `locationSharesVisibleTo` scoping: a public beacon is visible to any viewer (and hidden when `includePublic:false`); a `channel:` share is visible only to a viewer in that channel.

**Verification (all green):**

- `cd app && flutter analyze` → `No issues found!`
- `cd app && flutter test $(ls test/*.dart | grep -v screenshots_test.dart)` → **141 passed** (135 + 6 new).
- `cd cloud && go vet ./... && go test ./...` → all `ok`; `cd node && go vet ./... && go test ./...` → all `ok` (no Go changes; confirmed no regressions).
- `cd app && flutter build web --release` → `✓ Built build/web`.

**Browser click-through — what ran vs. what was substituted (honest record):**

- **Ran:** a single-shell-call orchestration (`/projects/sandbox/.toolchain/ptest/feat004.mjs`) built the cloud+node binaries into `/projects/sandbox/.toolchain/f4bin` (so they survive — `/tmp` is wiped between calls), copied the release web bundle into `cloud/web_run` and served it THROUGH the cloud same-origin (`WEB_DIR`, `CLIENT_API_KEYS=devkey`) on a fresh port (8088; 8080 can be held by a stale listener), ran the node on 8098, then with `puppeteer-core` + `/usr/local/bin/chrome` (headless, `--no-sandbox --disable-dev-shm-usage`, 412px) loaded the app in **two separate browser profiles (A, B)** with **geolocation granted** (`overridePermissions` + `setGeolocation` to the San Jose event location). Both booted `flutter-view` same-origin reading `/app-config.json` with **ZERO console/page errors** (benign favicon/manifest 404s ignored); screenshots saved to `/tmp/feat004_{A,B}_*.png`. Confirmed `/app-config.json` returned `{"apiKey":"devkey","baseUrl":""}`.
- **NOT driven through the Flutter UI:** adding the two profiles as contacts, selecting a contact + duration, tapping Share, and reading the marker on B's map. Reason: in this headless Chrome the Flutter **semantics tree published no `aria-label` nodes** even after clicking `flt-semantics-placeholder` (logged: `[A] semantics labels (home): []`), so the share → see → stop interaction is not tappable headlessly — the same limitation FEAT-003 recorded for contact-add/compose. The authoritative proof of the share/see/stop/expiry/non-audience behaviour is therefore the Dart fold test suite above (A shares→B sees; stop; clock-advance expiry; non-audience C sees nothing and gets no plaintext), which passes. No browser UI result is claimed that was not actually produced.

### 2026-10-24 — FEAT-005: provider completeness, HELP_REQUEST_CLOSED, cert depth limit (Item D)

Completed Item D: the protobuf schema change (`EVENT_TYPE_HELP_REQUEST_CLOSED`), owner-only request close, verified-provider-only mission assignment + carrier acceptance, author-only alert recall, auto-hide of expired supplies, and enforcement of certificate chain depth = 2. Every new rule got a fold change + an abuse test; docs were kept honest.

**Proto change + regen (the sensitive part):**

- `proto/resilience/v1/event.proto`: added `EVENT_TYPE_HELP_REQUEST_CLOSED = 24` (next unused number in the Help flows block 20–23) and `HelpRequestClosedBody { request_id, reason, closed_at_ms }`.
- Regenerated: `cd proto && buf generate` (protoc-gen-go v1.36.12 + protoc-gen-dart), then `cp cloud/gen/resilience/v1/{event,sync}.pb.go node/gen/resilience/v1/` (node/gen is a vendored byte-identical copy; `buf.gen.yaml` does not emit there). `git status --short app/lib/gen cloud/gen node/gen` showed ONLY the intended enum/message additions (`event.pb.dart`, `event.pbenum.dart`, `event.pbjson.dart`, `cloud/.../event.pb.go`, `node/.../event.pb.go`) — no spurious version churn. `cd cloud && go build ./...` and `cd node && go build ./...` both pass.

**What shipped (all grounded in existing patterns):**

- **Fold (`app/lib/state/derived_state.dart`).** Requests fold per `request_id` (first author owns the id). `HELP_REQUEST_CLOSED` sets `HelpRequestView.closed` ONLY when authored by the owner (owner-only; a close from any other key is ignored). Alerts fold per `alert_id`; only the original author may supersede/recall; the materialize step drops any alert whose latest `expires_ms` ≤ now (covers natural expiry AND an author recall via a same-`alert_id` re-issue with past expiry). New `ResourceView.isExpired(now)` and `WorldState.mapResources()` (ranked minus withdrawn minus expired) auto-hide supplies past `available_until_ms` from the map while keeping them in the projection (owner sees Expired in My Supplies).
- **Missions (`app/lib/logistics/mission.dart`, `app/lib/app/providers.dart`).** `MissionStore.missionsForViewer` gained an optional `isVerifiedProvider(author)` gate; `missionsProvider` passes `WorldState.provenanceOf == VERIFIED_ORG`. A `MISSION_CREATED`/`MISSION_MATCHED` from a non-provider is ignored (abuse rule). `DeliveriesScreen` renders the `MissionBucket` board (Assigned/Available/In transit/Awaiting handoff/Completed); a verified provider assigns a contact as carrier via `MISSION_MATCHED`, a carrier accepts via `MISSION_ACCEPTED`.
- **UI.** `my_posts_screen.dart`: My Requests shows Open/Closed status + a Close action (confirmation → `HELP_REQUEST_CLOSED`); My Supplies shows an Expired status. `map_screen.dart`: uses `mapResources()` and skips closed requests. `provider_screen.dart`: a Recall action on each live alert re-issues the same `alert_id` with `expires_ms` one minute in the past.
- **Trust (`app/lib/trust/org_certs.dart`).** `OrgCertGraph.provenanceOf` is now a depth-bounded BFS with `maxChainDepth = 2`: a trusted root is depth 0, a directly-certified key depth 1, one more hop depth 2 (badge), and depth 3+ confers NO badge. Shortest chain decides; revoked keys break their path; a visited set defeats cycles.
- **l10n.** New EN/ES keys in `strings_new.dart`, FR in `strings_fr.dart`, ZH in `strings_zh.dart` (completeness test still green).
- **Docs.** README "What works today" (Map/Supplies/Requests/Provider tools/Deliveries rows), `SPEC_PROVIDER_AND_FEATURES.md` (§1.1, §2, §3, §8), `KIRO_HANDOFF.md` (§4 marked DONE), and `DECISIONS.md` (depth-limit enforcement detail + a FEAT-005 section) updated honestly.

**Tests added (6; 141 → 147):**

- `app/test/derived_state_test.dart` (+5): owner closes a request; a non-owner close is ignored (abuse); alert recall hides the alert and a non-author cannot recall; a supply past `available_until_ms` is auto-hidden from the map but stays in the projection; a certificate chain of depth 3 grants no badge but depth 2 does.
- `app/test/mission_chain_test.dart` (+1): a verified provider may create+assign a mission while a non-provider create/assign is ignored (abuse).
- cloud/node forward opaque bodies, so no store/aggregator change was needed; existing Go suites confirm no regression.

**Verification (all green):**

- `cd proto && buf generate` + copy to `node/gen` → `git status --short app/lib/gen cloud/gen node/gen` shows only intended gen changes.
- `cd app && flutter analyze` → `No issues found!`
- `cd app && flutter test $(ls test/*.dart | grep -v screenshots_test.dart)` → **147 passed** (141 + 6 new).
- `cd cloud && go vet ./... && go test ./...` → all `ok`; `cd node && go vet ./... && go test ./...` → all `ok`.
- `cd app && flutter build web --release` → `✓ Built build/web`.

**Browser click-through — what ran vs. what was substituted (honest record):**

- **Ran:** a single-shell-call orchestration (`/projects/sandbox/.toolchain/ptest5/feat005.mjs`) built the cloud+node binaries into `/projects/sandbox/.toolchain/f5bin` (so they survive — `/tmp` is wiped between calls), served the release web bundle THROUGH the cloud same-origin (`WEB_DIR`, `CLIENT_API_KEYS=devkey`) on a fresh port (8085; freed first), ran the node on 8095, then with `puppeteer-core` + `/usr/local/bin/chrome` (headless, `--no-sandbox --disable-dev-shm-usage`, 412px) loaded the app in **two separate browser profiles (A, B)** with geolocation granted. Both booted `flutter-view` same-origin reading `/app-config.json` (`{"apiKey":"devkey","baseUrl":""}`) with **ZERO console/page errors** (benign favicon/manifest 404s ignored); screenshots saved to `/projects/sandbox/.toolchain/ptest5/feat005_{A,B}.png`. Scratch web dir and profiles cleaned up after; `cloud/web` restored (a cleanup `rm` had removed its tracked placeholder, `git checkout` restored it).
- **NOT driven through the Flutter UI:** assigning a mission as a provider, recalling an alert, accepting as a carrier from Deliveries, closing a request from My Requests, and confirming an expired supply is off the map. Reason: the confirmed platform limit from FEAT-003/004 — in this headless Chrome the Flutter **semantics tree publishes no `aria-label` nodes**, so UI tap-driven interaction is not achievable headlessly. The authoritative behavioral proof is the passing Dart fold/abuse suite above (owner-only close, non-provider assignment ignored, author-only alert recall, expired-supply auto-hide, cert depth 2 vs 3). No browser UI result is claimed that was not actually produced.

**Env reminders (unchanged):** prepend the toolchain env block + `ulimit -n 8192` to every shell call; build server binaries into a `/projects/sandbox` path (NOT `/tmp`) and run build+servers+puppeteer+teardown in ONE call; free ports first; remove any copied `cloud/web*` serving dir after (and restore `cloud/web` if a cleanup removes its tracked placeholder).

### 2026-10-24 — FEAT-006: offline PMTiles map (Item E) + remaining AI endpoints in the UI (Item F)

**Item E — offline map.** The node already serves `GET /node/v1/map/{region}.pmtiles` with HTTP Range (via `http.ServeContent`, `node/internal/packages`) and a `/node/v1/packages` catalog that lists each map region, so NO node change was needed. On the app side the new `app/lib/ui/map/pmtiles_tile_provider.dart` is a pure-Dart, web-safe flutter_map `TileProvider`: it opens the archive with `PmTilesArchive.fromUri` (the `pmtiles` package's HTTP backend, which the package's own support matrix lists as working on dart2js/browsers) and decodes RASTER tiles (png/jpeg/webp) with the Flutter engine's own `ImmutableBuffer.fromUint8List`. `PmTilesTileProvider.openRaster` returns null for vector archives (mvt/mlt), unknown types, or any network/parse failure, so the map transparently keeps the online OSM raster layer + the honest offline banner. `MapView` gained a `pmtilesUrl` param; `map_screen.dart` resolves it from the active node's catalog via the new `nodePmtilesUrlProvider` (+ `activeNodeProvider`) in `app/lib/app/providers.dart`. `maplibre_gl` was NOT added.

**Item F — AI in the UI.** `app/lib/ai/bedrock_ai_client.dart` already calls `/v1/ai/translate|summarize|dedup` with the `LocalRulesAiClient` fallback. Wired into the UI via the new reusable `app/lib/ui/components/translate_panel.dart` (Translate button → translated text + honest degraded chip, ORIGINAL always visible), placed on request/offer detail (`resource_detail_screen.dart` notes), the help-request detail sheet (`map_screen.dart` `_requestSheet`), and incoming message bubbles (`messages_screen.dart`). Home map gained an `_AiSummaryBar` → sheet that summarizes the folded world state (alerts + open requests + supplies) via `aiAssistProvider`. `help_flow_screen.dart` now runs a non-blocking AI dedup before submitting a help request; a near-duplicate pops an `AlertDialog` offering "View existing" / "Submit anyway" (rules fallback preserved).

**Honesty.** `AiAssist.summarize` was changed (client-side contract only) to return `SummaryResult{text,degraded}` so the Home summary's degraded chip reflects the REAL `/v1/ai/summarize` `degraded` flag (true when the rules fallback produced it, false only for a live cloud answer). The cloud HTTP endpoint contract was unchanged (it already returns `{summary,degraded}`), so `cloud/internal/api/server_test.go` was not touched. Translate shows the degraded chip whenever `degraded || !translated`; API-down falls back to rules and says so.

**l10n.** New keys (`map_offline_source`, `translate`, `translating`, `show_original`, `ai_translation`, `ai_degraded`, `translate_failed`, `summarize`, `ai_summary`, `summarizing`, `no_summary`, `dedup_warning_title`, `dedup_warning_body`, `view_existing`, `submit_anyway`) added to EN+ES (`strings_new.dart`), FR (`strings_fr.dart`), ZH (`strings_zh.dart`).

**Tests added (11; 147 → 158):**

- `app/test/ai_assist_test.dart` (+9): summarize now asserts the `degraded` flag; new UI-facing groups cover translate (live non-degraded / cloud-degraded-honest / API-down fallback), summarize (live vs API-down degraded), dedup (live hit / API-down rules paraphrase + unrelated), and a controllable `_FakeAiAssist` proving the degraded + offline behavior the widgets consume.
- `app/test/map_pmtiles_test.dart` (+2): `openRaster` returns null (never throws) for an unreachable node and for a garbage URL, so the OSM fallback engages.

**Verification (all green):**

- `cd app && flutter analyze` → `No issues found!`
- `cd app && flutter test $(ls test/*.dart | grep -v screenshots_test.dart)` → **158 passed** (147 + 11 new).
- `cd cloud && go vet ./... && go test ./...` → all `ok`; `cd node && go vet ./... && go test ./...` → all `ok`.
- `cd app && flutter build web --release` → `✓ Built build/web` (the gating check for Item E — the PMTiles import compiles fine on the JS web build; the wasm dry-run findings are pre-existing `flutter_secure_storage_web` noise and irrelevant since we use the JS build).

**Browser click-through — what ran vs. what was substituted (honest record):**

- **Ran (single shell call, `/projects/sandbox/.toolchain/ptest/feat006.mjs`):** built the cloud+node binaries into `/projects/sandbox/.agents/tmp/bin` (survive the `/tmp` wipe), generated a minimal valid raster (PNG) PMTiles region with `/projects/sandbox/AWS-13/.agents/tmp/make_pmtiles.dart` into `.agents/tmp/maps/testregion.pmtiles` (validated it opens + tile 0 reads via the `pmtiles` package), served the release web bundle THROUGH the cloud same-origin (`WEB_DIR`, `CLIENT_API_KEYS=devkey`, fresh port) with the node on a fresh port serving `--map-dir`. Verified the node's `/node/v1/packages` lists the map item and a `Range: bytes=0-126` request returns **206** with `Content-Range: bytes 0-126/216` + `Accept-Ranges: bytes` and the `PMTiles` magic. Then with `puppeteer-core` + `/usr/local/bin/chrome` (headless, `--no-sandbox --disable-dev-shm-usage`) booted the app in **two separate browser profiles** same-origin reading `/app-config.json` (`{"apiKey":"devkey","baseUrl":""}`) with **ZERO console/page errors** (benign favicon/manifest 404s ignored); screenshots in `/projects/sandbox/AWS-13/.agents/tmp/shots/profile{A,B}_{booted,map}.png`. This also proves the web build (incl. the PMTiles render path) loads cleanly in a real browser.
- **NOT driven through the Flutter UI:** tapping Translate on a detail/bubble, opening the Home summary sheet, and triggering the dedup dialog. Reason: the confirmed platform limit from FEAT-003/004/005 — the headless Flutter semantics tree publishes no `aria-label` nodes, so UI tap interactions are not achievable headlessly. The authoritative proof for translate/summarize/dedup (incl. the degraded flag and the offline fallback) is the passing `ai_assist_test.dart` suite, and for the PMTiles render path the web build + the node Range 206 verification + the zero-error boot. No browser UI result is claimed that was not actually produced.

**Env note:** do NOT `pkill -f chrome` — `/usr/local/bin/chrome` is the sandbox's own chromium and a broad pkill trips the sandbox (SIGKILL/143). Track only your own server PIDs and use fresh high ports instead of killing by name.

### 2026-10-24 — FEAT-007 (Item G): CORS, signed package manifest, docs honesty sweep + final report

Shipped the last item and finalized the docs.

**What shipped:**

- **Cloud CORS** (`cloud/internal/api/server.go`): a `withCORS` wrapper around the whole mux sends `Access-Control-Allow-Origin: *`, `-Methods: GET, HEAD, POST, OPTIONS`, `-Headers: Content-Type, Range, X-Api-Key, X-Org-Token, Authorization`, `-Expose-Headers`, and `-Max-Age: 86400`, answering `OPTIONS` preflight with `204`. Safe wildcard because auth is a header (`X-Api-Key`), never a cookie. Mirrors the node's existing CORS middleware. Test: `cloud/internal/api/cors_test.go`.
- **Node signed package manifest** (`node/internal/packages/manifest.go`): `GET /node/v1/manifest` returns `{manifest, public_key, signature, algorithm:"ed25519"}` — a detached Ed25519 signature over the canonical manifest (compact JSON, entries sorted by `(kind,name)`), SHA-256 per file. Verifiable against a trusted root; files are served with HTTP Range so a large download resumes. Enabled by `--packages-signing-key` / `PACKAGES_SIGNING_KEY` (64-byte key or 32-byte seed, hex); no key ⇒ `503` (refuses to serve an unsigned manifest). Tests: `manifest_test.go` (`TestManifestSignAndVerify`, `TestManifestEndpointServesSigned`, `TestManifestEndpoint503WithoutKey`, `TestRangeResumeDownload`).
- **App-side checksum verification** (`app/lib/nodes/package_manifest.dart`, `offline_downloads_screen.dart`, `app/lib/app/providers.dart`): `verifySignedManifest` verifies the manifest against `packagesTrustedRootProvider` (`--dart-define=PACKAGES_TRUSTED_ROOT=<hex>`) fail-closed; Offline Downloads shows an honest manifest-trust banner and a **Verify checksum** action that downloads a file and compares its SHA-256 to the signed entry. On-device background download/resume is honestly limited on web. l10n keys added EN/ES/FR/ZH. Test: `app/test/package_manifest_test.dart` (6 cases).
- **FEAT-005 deliverables verified (not re-implemented):** HELP_REQUEST close/cancel UI (`_closeRequest`→`HelpRequestClosedBody`, owner-only) in My Requests, and auto-hide of supplies past `available_until_ms` (`WorldState.mapResources()`/`ResourceView.isExpired`) — both present and left unchanged.
- **Docs honesty sweep:** README "What works today" (sync, messaging, location, map PMTiles, offline downloads + checksums, CORS, AI in UI), `docs/KIRO_HANDOFF.md` (A–G moved to "Already built"; remaining/partial listed), `docs/SPEC_PROVIDER_AND_FEATURES.md` status labels (map §2, node §4 signed manifest, downloads §5 checksum/resume, messaging §6 Built, provider §1.1 paths), and `docs/DECISIONS.md` (new FEAT-007 section: CORS policy, manifest signing scheme, fail-closed/503, checksum = trust boundary, web limits, blob storage location). Final report written at the TOP of this log.

**Verification (all green):**

- `cd app && flutter analyze` → `No issues found!`
- `cd app && flutter test $(ls test/*.dart | grep -v screenshots_test.dart)` → **164 passed** (158 + 6 new in `package_manifest_test.dart`).
- `cd cloud && go vet ./... && go test ./...` → all `ok` (incl. `cors_test.go`); `cd node && go vet ./... && go test ./...` → all `ok` (incl. `manifest_test.go`).
- `cd app && flutter build web --release` → `✓ Built build/web`.

**Browser click-through — what ran vs. what was substituted (honest record):**

- **Ran (single shell call, `/projects/sandbox/.toolchain/ptest/feat007.mjs`):** built the cloud+node binaries into `/projects/sandbox/.toolchain/f7bin`, generated a 32-byte signing seed + a 300-byte `region.pmtiles`, served the release web bundle THROUGH the cloud same-origin (`WEB_DIR`, `CLIENT_API_KEYS=devkey`) on fresh port 8187, the node with `--map-dir` + `--packages-signing-key` on 8197, and the SAME bundle from a DIFFERENT origin via `python3 -m http.server` on 8077. (1) **CORS win:** a page on `:8077` did a cross-origin `fetch` to the cloud on `:8187` — the GET `/healthz` read `{"status":"ok"}` and a preflighted `POST /v1/events/pull` with `X-Api-Key` returned `200` (a `curl -X OPTIONS` also showed `204` + all CORS headers incl. `X-Api-Key`). This is the one case where cross-origin is the point, and it now works. (2) **Signed manifest + checksum:** fetched `/node/v1/manifest`, verified the detached Ed25519 signature against the embedded key using a JS reconstruction of the SAME canonical bytes (so Go↔Dart↔JS canonical parity is demonstrated), then did a two-part **Range** download (`bytes=0-49` 206, `bytes=50-` 206), reassembled, and confirmed SHA-256 matched the signed entry; a flipped byte failed the check (negative control). (3) **Baseline:** booted the app in **two profiles** same-origin with **ZERO console/page errors**. Screenshots in `/projects/sandbox/AWS-13/.agents/tmp/shots7/`.
- **NOT driven through the Flutter UI:** tapping Offline Downloads → Check node → Verify checksum inside the app. Reason: the confirmed FEAT-003/004/005 limit (headless Flutter semantics publishes no `aria-label` nodes). The checksum/resume behavior is proven instead by `manifest_test.go` `TestRangeResumeDownload`, the Dart `package_manifest_test.dart`, and the real cross-origin/manifest browser steps above. No UI result is claimed that was not produced.

**Env notes (unchanged):** prepend the env block + `ulimit -n 8192`; build server binaries into `/projects/sandbox` (not `/tmp`); free/choose fresh ports; do servers+puppeteer+teardown in ONE call; never `pkill -f chrome`. Scratch dirs cleaned up after the run.

### 2026-10-24 Review v1 follow-up: the three non-blocking findings addressed

The v1 semantic review (`.agents/tasks/task-overnight-resilience/2026-10-24-103142-review.md`) returned **APPROVED** with three non-blocking findings. All three are now fixed (no deferrals). Full rationale is in `docs/DECISIONS.md` → "Review v1 follow-up".

**What changed:**

- **(1) Signed-manifest canonicalization cross-language escaping (possible).** `Manifest.CanonicalBytes()` in `node/internal/packages/manifest.go` now marshals through a `json.Encoder` with `SetEscapeHTML(false)` (and trims the trailing newline `Encode` appends) so Go stops escaping `<`/`>`/`&` to `\u003c`/`\u003e`/`\u0026`, matching Dart's `jsonEncode`. Without this, a manifest `name`/`path` containing a literal `&` (ordinary in filenames) would have produced diverging preimages and a false `badSignature` on device. The Dart canonicalizer already did not escape; only its comment was corrected. New regression tests on BOTH sides: Go `TestCanonicalBytesNoHTMLEscape` + `TestManifestSignVerifyWithSpecialChars`; Dart `canonical bytes keep literal & < >` + `verifies a signed manifest whose path contains & < >`.
- **(2) Public-beacon share bypassed the position seam (confirmed, minor).** Added `LocationCoordinator.readPosition()` (a public accessor over the injectable `_readPosition` seam) and routed `_sharePublicBeacon` in `location_share_screen.dart` through it instead of the top-level `readPosition()`, so the public-beacon path is now test-substitutable exactly like the contact path.
- **(3) Alert recall ordering relied on lamport only (possible).** The alert fold in `app/lib/state/derived_state.dart` now supersedes same-author alert events by `(lamport, created_at_ms)` instead of `lamport >= prev` alone: lamport stays primary (the per-author `LamportClock` is monotonic, so an honest author's recall advances it) and `created_at_ms` (already in `EventHeader`) breaks the tie, fixing the out-of-order recall case where a recall shares the original's lamport (e.g. from a second device/session) but carries a later wall-clock. No proto change (EmergencyAlertBody has no `seq`; adding one was heavier than warranted). New test: `derived_state_test.dart` "alert recall out of order (equal lamport, later created_at) still supersedes".

**Verification (all green):**

- `cd app && flutter analyze` → `No issues found!`
- `cd app && flutter test $(ls test/*.dart | grep -v screenshots_test.dart)` → **167 passed** (164 prior + 3 new: 2 in `package_manifest_test.dart`, 1 in `derived_state_test.dart`).
- `cd cloud && go vet ./... && go test ./...` → all `ok`.
- `cd node && go vet ./... && go test ./...` → all `ok` (incl. the two new manifest cases).
- `cd proto && buf generate` + copy to `node/gen` → **no diff** in `app/lib/gen` / `cloud/gen` / `node/gen` (no proto change was needed for any of the three fixes).
- `cd app && flutter build web --release` → `✓ Built build/web`.
