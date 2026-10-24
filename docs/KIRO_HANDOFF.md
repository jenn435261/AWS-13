# Handoff: finish the unconnected features

Written for an engineer (or Kiro) picking this up cold. Everything below is verified against the code as of the
merge of PR #1. Do the tasks in order; each has an acceptance test. Keep the rule that has held so far:
**the UI must never claim something works that is not wired.** If a feature is not connected, show an honest state.

## Live system

- App + API: https://resilience.chrisccluk.live (Heroku app `resilience-api-chris-83ac9d67094f`).
- Deploy: `scripts/deploy-heroku.ps1` (needs Flutter on PATH; builds web, copies into `cloud/web`, subtree-pushes `cloud/`).
- Config vars and domain steps: `cloud/DEPLOY_HEROKU.md`. Event AWS creds are temporary STS creds and **expire at event end**.
- AWS Lambda/CDK cannot be deployed in the event account (`iam:CreateRole` denied). Do not retry.

## What actually works (verified in a real browser against the live site)

| Area | State |
|---|---|
| Need Help / Offer Help | Signed event written to local SQLite (WASM on web), shown in My Requests / My Supplies |
| Contacts | Add by pasted code / QR payload, list, detail, remove + undo; stored locally |
| Network Status | Real probe of `GET /healthz` with latency and last-checked time |
| AI structure | `help_flow_screen.dart` calls `POST /v1/ai/structure` -> Bedrock (`degraded:false` live). Falls back to rules offline |
| AI translate / summarize / dedup | Endpoints live and tested (translate verified live), **no UI calls them** |
| Gate | `/v1/events*`, `/v1/ai/*` need `X-Api-Key`; web gets first key from `/app-config.json` |

## What is NOT connected (your work)

### 1. App-side cloud sync client (do first; 2 and 3 depend on it)
The API has `POST /v1/events` and `GET /v1/events/pull`, and `sync_engine.dart` exists for peer sync, but the app never
pushes or pulls against the cloud. Build `app/lib/sync/cloud_sync.dart`:
- On every local event write, push unsent events (track a high-water mark in the KeyValue table).
- Periodically and on app focus, pull since the last cursor and ingest through the existing event validation
  path (signature + hybrid-logical-clock checks) so a forged event is rejected.
- Use `cloudBaseUrlProvider` and `cloudApiKeyProvider` (`app/lib/app/providers.dart`). Send `X-Api-Key`.
- Surface the result in Network Status ("Last synced", count pending).
- Acceptance: two browser profiles on the live site; a request created in A appears in B's map/list within 30 s.
  Add a Dart test with `MockClient`, and a Go test if the API changes.
- Cloud store is **in-memory** on Heroku. Provision Heroku Postgres and set `RESILIENCE_PG_DSN` so events survive restarts
  (`heroku addons:create heroku-postgresql:essential-0`; check how `cloud/cmd/api/main.go` reads the DSN).

### 2. Secure messaging (Signal)
Today `messages_screen.dart` shows a "not connected" empty state; fake chats were removed. Pieces already in
`app/lib/messaging/`: `secure_session.dart`, `signal_keys.dart`, `message_flow.dart`, `conversation_view.dart`.
Missing:
- **Durable Signal store.** The session/prekey/identity stores are in-memory, so a reload loses all sessions.
  Back them with Drift (new table or the KeyValue table). Never store private keys unencrypted on web beyond what
  `identity_store.dart` already does; note the trade-off in the README.
- **Prekey bundle publication.** Publish your bundle (identity key, signed prekey, one-time prekeys) as a signed
  event or a new `PUT/GET /v1/prekeys/{resilienceId}` endpoint (gate it like the others). Fetch a contact's bundle
  when opening a chat with them.
- **Delivery.** Send ciphertext as an event addressed to the recipient; the sync client (task 1) carries it. The
  recipient decrypts on ingest.
- **UI.** Chat list = contacts with messages; tap a contact -> `conversation_view.dart`. Replace `_notConnected`.
- Acceptance: A and B add each other by code, A sends "hello", B sees it after a reload of B. Add a test of
  X3DH + double ratchet round trip through the Drift-backed store.

### 3. Location sharing
`location_share_screen.dart`: durations (15m / 1h / 4h / 24h / Until I stop) exist; the Share button is
**disabled** (`onPressed: null`) and a note says it is not connected. Build:
- A position source: `geolocator` (works on web via browser permission). Ask for permission only on Share.
- Encrypt position to the chosen contacts (reuse task 2), send as a short-lived event with an expiry equal to the
  chosen duration (null = indefinite until stopped). Stop button must publish a revoke.
- Recipient side: show on a simple list/map of "people sharing with you". `maplibre_gl` was removed because it
  breaks the web build; use a list, or a web-safe map (e.g. `flutter_map` with OSM tiles) if you want a map.
- Then enable the button and remove the `location_not_connected` note.

### 4. Use the other AI endpoints
- Translate: add a "Translate" action on a request/offer detail and on messages (`ai.translate(text, from, to)`).
  Server field names are `text`, `from`, `to`.
- Summarize: situation summary on Home from `worldState`.
- Dedup: warn on submit if a near-duplicate request exists nearby.
- Look at `app/lib/ai/bedrock_ai_client.dart`; every call has a rules fallback, keep it.

### 5. Smaller items
- Add by username / phone was removed (no directory backend). Only add back with a real lookup endpoint.
- API sends no CORS headers; only matters if the web app is ever hosted on a different origin than the API.
- Offline Downloads and Resilience Node screens work against a node you type in; there is no discovery.
- LoRa is "Not supported yet" (honest state). Nearby peers is "unavailable here" on web.
- `screenshots_test.dart` has a hard-coded sandbox font path; it is excluded from the 107-test run.

## Gotchas learned the hard way

- **Drift on web**: `app/web/sqlite3.wasm` and `app/web/drift_worker.js` must match `drift 2.35.3` / `sqlite3 3.8.0`
  (pinned in `pubspec.yaml`). A mismatch makes every DB write throw `WebAssembly.instantiate(): Import #25 "env"`.
- **dart2js** rejects 64-bit integer literals (see `_blakeIv` in `identity_keys.dart`, parsed from hex strings).
  `flutter build web --wasm` fails because of plugins; use the JS build.
- Do not add `maplibre_gl`; its web plugin breaks the build.
- `SnackBar` with an action never auto-dismisses unless `persist: false` (set in `toast.dart`).
- Controllers owned by dialogs must live in a `StatefulWidget` (see `_EnterCodeDialog`), or you get
  "used after being disposed".
- Windows needs Developer Mode on for Flutter plugin symlinks.

## How to verify (do not skip: unit tests alone missed every bug above)

1. `cd app && flutter analyze && flutter test` (skip `screenshots_test.dart`), and
   `cd cloud && go test ./...`.
2. `flutter build web --release`, serve it, and click every flow in a real browser. The headless harness used
   puppeteer-core + Flutter's semantics tree (click `flt-semantics-placeholder` first, tap the smallest
   `flt-semantics` node matching a label). Watch the console for `pageerror`.
3. Redeploy with `scripts/deploy-heroku.ps1` and repeat against the live domain.
