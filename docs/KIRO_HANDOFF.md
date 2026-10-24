# Handoff: what is left

Written for an engineer (or Kiro) picking this up cold. Read `docs/SPEC_PROVIDER_AND_FEATURES.md` first: it
defines roles, the map, supplies, nodes, packages, media messages and languages, and says which parts are built.
Rule that has held so far: **the UI must never claim something works that is not wired.** If it is not connected,
show an honest state.

## Live system

- App + API: https://resilience.chrisccluk.live (Heroku app `resilience-api-chris-83ac9d67094f`).
- Deploy: `scripts/deploy-heroku.ps1` (needs Flutter on PATH; builds web, copies into `cloud/web`, subtree-pushes `cloud/`).
- Config vars and domain steps: `cloud/DEPLOY_HEROKU.md`. Event AWS creds are temporary STS creds and **expire at event end**.
- AWS Lambda/CDK cannot be deployed in the event account (`iam:CreateRole` denied). Do not retry.
- Proof-of-concept node: `cd node && go run ./cmd/resilience-node --name "My Node" --http-addr :8090 --map-dir … --apk-dir … --readiness-dir …`
  then open `http://localhost:8090/node/v1/pair.png` and scan it from the app, or add `localhost:8090` by hand.

## Already built (do not redo)

Real map; supply create / edit / restock / out of stock / take down / relist with quantity, unit, date and location;
provider tools (verified supplies, alerts, missions, certify a contact); trusted organizations (persisted);
saved nodes with QR pairing, rename, active, delete; offline package library with versions; node catalog,
pairing QR and CORS; French and Mandarin; owner-only edits and verified-only alerts enforced in the fold.
Tests: `supply_and_provider_test.dart`, Go `internal/pairing`, `internal/packages` catalog.

## Still not connected (your work, in this order)

### 1. App-side cloud sync client (do first; 2 and 3 depend on it)
The API has `POST /v1/events` and `GET /v1/events/pull`, and `sync_engine.dart` exists for peer sync, but the app
never pushes or pulls. Build `app/lib/sync/cloud_sync.dart`:
- Push unsent local events (high-water mark in the KeyValue table); pull since a cursor; ingest through
  `EventStore.apply` so signatures and clock checks reject forgeries.
- Also sync with the **active saved node** (`/node/v1/push`, `/node/v1/pull`, `/node/v1/have`).
- Use `cloudBaseUrlProvider` and `cloudApiKeyProvider` (`app/lib/app/providers.dart`), header `X-Api-Key`.
- Show "Last synced / N pending" in Network Status.
- Acceptance: two browser profiles on the live site; a request or alert created in A appears in B within 30 s.
  Provider alerts, missions, supplies and certificates only reach other people once this exists.
- The cloud store is in-memory on Heroku. Provision Postgres (`heroku addons:create heroku-postgresql:essential-0`) and set
  `RESILIENCE_PG_DSN` so events survive restarts.

### 2. Secure messaging, with photos and audio
Today `messages_screen.dart` shows a "not connected" state. Engines exist in `app/lib/messaging/`.
Missing: durable Signal store (Drift-backed), prekey bundle publication and fetch, delivery via the sync client, chat UI.
Media design is in the spec §6 (encrypted blobs, size limits, blob endpoints on cloud and node). Build text first,
then images, then audio. Acceptance: A and B add each other, A sends text, a photo and a voice note, B sees all three after a reload.

### 3. Location sharing
`location_share_screen.dart`: durations exist, the Share button is disabled. `position_service.dart` already reads a
one-shot position. Build: encrypt to chosen contacts (task 2), send a short-lived `LOCATION_SHARE` event with an expiry
(null = until stopped), publish `LOCATION_STOP` on stop, show "people sharing with you". Then enable the button.

### 4. Provider gaps (spec §1.1) — DONE (FEAT-005)
Shipped: a Missions board for providers + carriers in the Deliveries tab (`deliveries_screen.dart`, buckets from
`logistics/mission.dart`); **verified-provider-only** mission create/assign via `MISSION_MATCHED` (a non-provider
create/assign is ignored in the fold — abuse rule) and carrier accept via `MISSION_ACCEPTED`; **alert recall** = a new
`EMERGENCY_ALERT` with the same `alert_id` and `expires_ms` in the past, author-only (Recall action on the provider
screen); **request close** via the new `EVENT_TYPE_HELP_REQUEST_CLOSED = 24` event + `HelpRequestClosedBody` (owner-only
close from My Requests; a close from any other key is ignored); **auto-hide supplies** past `available_until_ms` from the
map (`WorldState.mapResources()`), shown as Expired in My Supplies; **certificate chain depth limit = 2** enforced in
`OrgCertGraph.provenanceOf` (depth 3+ grants no badge). All with fold + abuse tests; proto regenerated for Dart + Go and
copied into `node/gen`. See `docs/DECISIONS.md` (FEAT-005) and `docs/OVERNIGHT_LOG.md`.

### 5. Offline map
Serve PMTiles from a node and render them (spec §2). OSM raster tiles are a demo-grade stopgap.

### 6. Use the other AI endpoints
Translate (`text`, `from`, `to`) on request/offer details and messages; summarize on Home; dedup warning on submit.
See `app/lib/ai/bedrock_ai_client.dart`; keep the rules fallback.

### 7. Smaller items
- Add by username / phone was removed (no directory). Only add back with a real lookup endpoint.
- API sends no CORS headers; only matters if the web app is hosted on another origin.
- A https page cannot reach a plain-http LAN node (mixed content). Native app is fine; for web give the node HTTPS.
- Node discovery (mDNS), signed package manifests, on-device download with resume and checksums.
- `screenshots_test.dart` has a hard-coded sandbox font path; it is excluded from the normal test run.

## Gotchas learned the hard way

- **Drift on web**: `app/web/sqlite3.wasm` and `app/web/drift_worker.js` must match `drift 2.35.3` / `sqlite3 3.8.0`
  (pinned in `pubspec.yaml`). A mismatch makes every DB write throw `WebAssembly.instantiate(): Import #25 "env"`.
- dart2js rejects 64-bit integer literals (see `_blakeIv` in `identity_keys.dart`). `flutter build web --wasm` fails because of plugins; use the JS build.
- Do not add `maplibre_gl` (breaks the web build). The map uses `flutter_map`.
- `SnackBar` with an action never auto-dismisses unless `persist: false` (set in `toast.dart`).
- Controllers owned by dialogs must live in a `StatefulWidget` (see `_EnterCodeDialog`, `_NameDialog`).
- A proto3 `bool=false` update is the same bytes as "unset"; relist re-publishes the resource instead (see `supply_service.dart`).
- Windows needs Developer Mode for Flutter plugin symlinks.

## How to verify (unit tests alone missed every bug so far)

1. `cd app && flutter analyze && flutter test` (skip `screenshots_test.dart`), `cd cloud && go test ./...`, `cd node && go test ./...`.
2. `flutter build web --release`, serve `build/web`, click every flow in a real browser. The headless harness used
   puppeteer-core + Flutter's semantics tree (click `flt-semantics-placeholder` first; tap the smallest `flt-semantics`
   node matching a label; text fields need coordinate taps; lists are lazy so scroll before tapping lower items).
   Grant geolocation to test the map. Watch the console for `pageerror`.
3. Redeploy with `scripts/deploy-heroku.ps1` and repeat against the live domain.
