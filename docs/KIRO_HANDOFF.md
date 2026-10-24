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

Real map (online OSM raster + **offline PMTiles raster from a node** with an honest offline banner); supply
create / edit / restock / out of stock / take down / relist with quantity, unit, date and location, and
auto-hide of supplies past `available_until_ms`; provider tools (verified supplies, alerts + **recall**, missions +
**carrier assign/accept**, certify a contact, **certificate chain depth limit = 2**); **request close/cancel**
(owner-only) in My Requests; trusted organizations (persisted); saved nodes with QR pairing, rename, active, delete;
offline package library with versions; node catalog, pairing QR and CORS; French and Mandarin; owner-only edits and
verified-only alerts enforced in the fold.

**Items A–G from the overnight run are done:**

- **A — App-side cloud + node sync client** (`app/lib/sync/cloud_sync.dart`, `sync_providers.dart`): pushes unsent
  local events and pulls new ones from the cloud (`/v1/events`, `/v1/events/pull`) and from a node
  (`/node/v1/push`, `/node/v1/pull`); every pulled event ingested through `EventStore.apply` (verify-before-store);
  visible status in Network Status, exponential backoff, honest offline handling. Tests: `cloud_sync_test.dart`,
  `sync_engine_test.dart`.
- **B — Secure messaging (text + photo + audio)** (`app/lib/messaging/*`, `messages_screen.dart`): durable
  Drift-backed Signal store, prekey bundles published as signed events, AES-256-GCM attachments as content-addressed
  opaque blobs, delivery states. Tests: `messaging_e2e_test.dart`, `signal_messaging_test.dart`, `message_flow_test.dart`,
  `photo_prep_test.dart`.
- **C — Location sharing** (`location_share_screen.dart`, `location/*`): opt-in, rounded ~110 m (or exact), E2E to
  chosen contacts, time-boxed + revocable, folds into map/list and auto-expires; author-only stop. Tests:
  `location_share_test.dart`, `location_view_test.dart`, fold/abuse cases in `derived_state_test.dart`.
- **D — Provider completeness** (proto `EVENT_TYPE_HELP_REQUEST_CLOSED = 24`, depth-limit = 2): see FEAT-005 below.
- **E — Offline PMTiles map** (`app/lib/ui/map/pmtiles_tile_provider.dart`): see FEAT-006 below.
- **F — AI endpoints in the UI** (Home summary bar, translate panel, pre-submit dedup): see FEAT-006 below.
- **G — Smaller gaps**: **cloud CORS** (preflight + `X-Api-Key`, mirrors the node), **node-served signed package
  manifest** with SHA-256 checksums + HTTP Range-resume, app-side **checksum verification against the signed
  manifest** before trusting a download. See FEAT-007 below.

Tests: `supply_and_provider_test.dart`, `package_manifest_test.dart`, Go `internal/pairing`, `internal/packages`
(catalog + manifest + Range-resume), `internal/api` (CORS preflight).

## Still open / partial

- **Nearby peers (BLE/Wi-Fi Direct)**: `nearby_service` transport exists but is unavailable in browsers and not
  exercised on-device in this run.
- **LoRa**: not set up.
- **Node discovery (mDNS)**: not implemented (nodes are added by QR or typed address).
- **Mixed content on web**: an HTTPS page cannot reach a plain-HTTP LAN node; give the node HTTPS for web use
  (native is fine). The signed-manifest checksum flow therefore verifies best from a native build or an HTTPS node.
- **Cloud event store** is in-memory on Heroku unless `RESILIENCE_PG_DSN` is set
  (`heroku addons:create heroku-postgresql:essential-0`).
- **Add by username / phone** stays removed (no directory); only restore with a real lookup endpoint.
- `screenshots_test.dart` has a hard-coded sandbox font path; it is excluded from the normal test run.

### Reference: Provider gaps (spec §1.1) — DONE (FEAT-005)
Shipped: a Missions board for providers + carriers in the Deliveries tab (`deliveries_screen.dart`, buckets from
`logistics/mission.dart`); **verified-provider-only** mission create/assign via `MISSION_MATCHED` (a non-provider
create/assign is ignored in the fold — abuse rule) and carrier accept via `MISSION_ACCEPTED`; **alert recall** = a new
`EMERGENCY_ALERT` with the same `alert_id` and `expires_ms` in the past, author-only (Recall action on the provider
screen); **request close** via the new `EVENT_TYPE_HELP_REQUEST_CLOSED = 24` event + `HelpRequestClosedBody` (owner-only
close from My Requests; a close from any other key is ignored); **auto-hide supplies** past `available_until_ms` from the
map (`WorldState.mapResources()`), shown as Expired in My Supplies; **certificate chain depth limit = 2** enforced in
`OrgCertGraph.provenanceOf` (depth 3+ grants no badge). All with fold + abuse tests; proto regenerated for Dart + Go and
copied into `node/gen`. See `docs/DECISIONS.md` (FEAT-005) and `docs/OVERNIGHT_LOG.md`.

### Reference: Offline map (spec §2) — DONE (FEAT-006)
`app/lib/ui/map/pmtiles_tile_provider.dart` is a pure-Dart, web-safe `flutter_map` tile provider that opens a node's
PMTiles archive over HTTP (Range) and decodes **raster** tiles; `MapView` uses it when the active node advertises a
map in its catalog, and falls back to the online OSM raster layer with an honest offline banner otherwise. The node
already serves `GET /node/v1/map/{region}.pmtiles` with Range (206).

### Reference: AI endpoints in the UI — DONE (FEAT-006)
Translate panel on resource notes / help-request details / incoming messages, Home summary bar, and a non-blocking
dedup check before submitting a request. The original text is always kept; a degraded chip reflects the real
`degraded` flag; API-down falls back to local rules. See `app/lib/ai/*` and `app/lib/ui/components/translate_panel.dart`.

### Reference: Smaller gaps — DONE (FEAT-007)
- **CORS**: the cloud API (`cloud/internal/api/server.go`, `withCORS`) sends `Access-Control-Allow-{Origin,Methods,Headers}`
  (headers include `X-Api-Key`) and answers OPTIONS preflight with 204, mirroring the node's policy. Test:
  `cloud/internal/api/cors_test.go`.
- **Signed package manifest**: the node serves `GET /node/v1/manifest`
  (`node/internal/packages/manifest.go`) — a detached Ed25519 signature over the canonical manifest, SHA-256 per entry,
  verifiable against a trusted root; files are served with HTTP Range so a large PMTiles download can resume. Enable
  with `--packages-signing-key <hex-key-file>` (or `PACKAGES_SIGNING_KEY`); without it the endpoint returns 503 (the
  node refuses to serve an unsigned manifest). Tests: `node/internal/packages/manifest_test.go` (sign/verify +
  Range-resume).
- **App-side checksum verification**: `app/lib/nodes/package_manifest.dart` verifies the signed manifest against
  `packagesTrustedRootProvider` (`--dart-define=PACKAGES_TRUSTED_ROOT=<hex>`), then Offline Downloads can verify a
  downloaded file's SHA-256 against the signed manifest before trusting it; honest manifest state is shown otherwise.
  Test: `app/test/package_manifest_test.dart`. On web, on-device file download/resume is limited (no filesystem), so
  the checksum check fetches the bytes over HTTP where the platform allows; the UI never claims a verification it did
  not perform.

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
