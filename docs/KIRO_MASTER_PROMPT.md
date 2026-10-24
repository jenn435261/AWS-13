# Master prompt for Kiro (paste everything below the line)

---

You are the sole engineer on the Resilience Network repo for the next several hours. Nobody is available to answer questions. Work autonomously from start to finish without stopping to ask, without splitting the work into phases that wait for approval, and without handing back partial results. When something is ambiguous, pick the safest reasonable option, write the decision down in `docs/DECISIONS.md`, and keep going. Stop only when every item in "Definition of done" is true and verified, or when you are blocked by something listed under "Hard limits".

## What this project is

An offline-first, encrypted, disruption-tolerant emergency coordination app. Monorepo:
- `app/` Flutter (Riverpod, Drift SQLite incl. WASM on web, Signal protocol via `libsignal_protocol_dart`, `flutter_map`, `geolocator`, `mobile_scanner`, `qr_flutter`).
- `cloud/` Go API (net/http), in-memory or Postgres store, Amazon Bedrock AI endpoints with rules fallback. Deployed on Heroku, also serving the Flutter web build. Live at https://resilience.chrisccluk.live.
- `node/` Go "Resilience Node" daemon (event cache, sync server, packages, pairing QR).
- `proto/` protobuf event model. `infra/` CDK (do not touch: the event AWS account cannot deploy it).

Read these first, in this order, before writing code: `docs/KIRO_HANDOFF.md`, `docs/SPEC_PROVIDER_AND_FEATURES.md`, `README.md` ("What works today"), `cloud/DEPLOY_HEROKU.md`, `node/README.md`. They are the source of truth for what is built, what is not, and the gotchas that already cost hours.

## Non-negotiable rules

1. **Never claim something works that is not wired.** If a feature is not connected, the UI shows an honest state. No fake data, no placeholder chats, no disabled buttons that look active.
2. **Everything is a signed event.** New state is new event types or fields folded in `app/lib/state/derived_state.dart`. Verify signatures before storing. Only owners edit their own things; only verified authors issue alerts. Add the rule to the fold and a test for the abuse case.
3. **Privacy by default.** Location is opt-in, rounded (~110 m) unless explicitly exact, expiring, revocable, end-to-end encrypted to chosen contacts. Strip EXIF from photos. Never log message content, keys or coordinates.
4. **Secrets never enter git.** The cloud client key comes from `/app-config.json` on web and `--dart-define=CLOUD_API_KEY` on native. AWS credentials are temporary and live only in Heroku config vars. If you find a secret in the repo, remove it and note it in the final report.
5. **Match the surrounding code** (naming, comment density, hand-written providers, no codegen except Drift). Keep text in `lib/l10n/` for all four languages (en, es, fr, zh); a test fails if fr or zh miss a key.
6. Run all UI text at >= 16px, keep primary actions at the bottom, keep toasts at 5 s, keep action clutter in expanding bottom buttons, not rows of buttons.

## Hard limits (stop and report instead of working around)

- Do not run, edit or retry anything under `infra/` or `cdk`. Do not try to create IAM roles.
- Work on a new branch off `feature/provider-map-supplies` (or `main` if that is merged), named `kiro/overnight`. **Do not push to or force-push `main`, do not merge any PR, do not delete branches you did not create.** Open a PR at the end and leave it for the human.
- Do not run `heroku` destructive commands (no `apps:destroy`, no config var deletion, no DB resets). A deploy with `scripts/deploy-heroku.ps1` is allowed only if the Heroku CLI is already authenticated on this machine; otherwise skip deploy and say so in the report.
- Do not kill processes you did not start. Do not disable tests, skip tests, loosen assertions or add `--no-verify` to make things pass. A failing test means fix the code or the test's real mistake, and explain which.
- Do not add dependencies that break the Flutter web build. Known bad: `maplibre_gl`. `flutter build web --wasm` is expected to fail; use the JS build.

## The work, in dependency order (do all of it; do not stop between items)

**A. App-side cloud + node sync client** (everything else depends on it).
Push unsent local events and pull new ones against (1) the cloud `POST /v1/events`, `GET /v1/events/pull` with `X-Api-Key`, and (2) the active saved node `/node/v1/push|pull|have`. Track high-water marks in the KeyValue table. Ingest through `EventStore.apply` so forged events are rejected. Sync on start, on app focus, after every local write, and every 30 s while visible, with backoff. Surface "Last synced / N pending / error" in Network Status. Provision Postgres on the cloud side if `RESILIENCE_PG_DSN` is supported by `cloud/cmd/api/main.go` and document the Heroku command; do not run it unless the CLI is authenticated.
Acceptance: two browser profiles on the same server; a request, supply, alert and certificate created in A appear in B within 30 s, with B showing the correct verified/community badge. Automated: a Dart test with a fake transport plus a Go test for any API change.

**B. Secure messaging with photos and audio.**
Durable Drift-backed Signal stores (identity, prekeys, signed prekeys, sessions, sender keys). Publish prekey bundles (`EVENT_TYPE_PREKEY_BUNDLE` or a gated `/v1/prekeys/{id}` endpoint, your choice, document it). Chat list = contacts with messages; conversation view with delivery states. Then attachments exactly as designed in the spec section 6: encrypted blob, random 256-bit key inside the E2E message, content-addressed `PUT/GET /v1/blobs/{sha256}` on cloud and `/node/v1/blobs/{sha256}` on node, 2 MB cap, rate limit, 7-day purge, hash verified after decrypt. Photos re-encoded <= 1600 px with inline thumbnail and EXIF stripped; audio Opus/AAC mono <= 60 s with hold-to-record, cancel, play, duration. Replace the "not connected" state in `messages_screen.dart` only when this really works.
Acceptance: A and B add each other by code; A sends text, a photo and a voice note; B receives all three after a full page reload; the server and any relay store only ciphertext (assert this in a Go test by inspecting stored bytes).

**C. Location sharing.**
Enable the Share button using `position_service.dart`. Encrypt to the chosen contacts (reuse B), send `LOCATION_SHARE` with an expiry equal to the chosen duration (15 m / 1 h / 4 h / 24 h / until stopped), publish `LOCATION_STOP` on stop, show "people sharing with you" on the map and a list. Remove the `location_not_connected` note when it works.
Acceptance: A shares with B for 15 m, B sees A on the map; A stops, B's marker disappears; expiry removes it without a stop; a non-audience contact C never sees it.

**D. Provider completeness.**
Mission list and assignment for providers (`MISSION_MATCHED`), carriers accepting from Deliveries, alert recall (same `alert_id`, expiry in the past), request close (`HELP_REQUEST_CLOSED` event type, add to proto and regenerate Dart and Go, update `README`/spec), auto-hide supplies past `available_until_ms`, and the certificate depth limit decided in spec section 8 (use depth 2 and record it in `docs/DECISIONS.md`). Add the abuse tests (non-owner cannot close, non-provider cannot assign).

**E. Offline map.**
Serve and render PMTiles from the active node (`/node/v1/map/{region}.pmtiles`, Range requests) with OSM raster as the online fallback. Pick a pure-Dart/web-safe approach; verify the web build still compiles.

**F. Use the remaining AI endpoints in the UI.**
Translate (`text`, `from`, `to`) on request/offer detail and message bubbles; summarize on Home from world state; dedup warning before submitting a near-duplicate request. Keep the rules fallback and the `degraded` indicator honest.

**G. Smaller gaps.**
Auto-hide expired supplies (if not done in D), node-served signed package manifest with checksum verification and Range-resume download where the platform allows, CORS headers on the cloud API for cross-origin web hosts, `HELP_REQUEST` cancel UI in My Requests.

If you finish early, spend the remaining time on hardening: fuzz the event decoder, add property tests for the fold (order independence, idempotence), and re-run the whole verification below.

## How to verify (this is the most important section)

Unit tests alone have missed every real bug in this project (a WASM/driver mismatch broke every database write in the browser and all tests passed). So:

1. After each item: `cd app && flutter analyze` (must be clean) and `flutter test` (all except `test/screenshots_test.dart`, which has a hard-coded font path); `cd cloud && go vet ./... && go test ./...`; `cd node && go vet ./... && go test ./...`.
2. **Real browser click-through for every user-visible change.** `cd app && flutter build web --release`, serve `build/web` locally, run the cloud API and a node locally (`go run ./cmd/api`, `go run ./cmd/resilience-node`), and drive the app with puppeteer-core + Chrome. Method that works: load the page, click `flt-semantics-placeholder` to enable the semantics tree, tap the smallest `flt-semantics` element whose label matches the visible text, tap text fields by coordinates then type with `page.keyboard.sendCharacter`, scroll with `page.mouse.wheel` because lists are lazy, grant geolocation with `overridePermissions` + `setGeolocation`, and fail the run on any `pageerror` or console `error`. Take a screenshot after every step and actually look at them.
3. **Two-profile tests** for anything that crosses devices (sync, messaging, location, alerts, certificates): two separate browser contexts against the same server.
4. Test the abuse case for every rule you add (forged event, wrong owner, expired, revoked key, tampered ciphertext).
5. Test failure states: API down, node unreachable, location denied, camera unavailable, offline. Each must show an honest message, never a crash or a spinner forever.
6. Test all four languages render without overflow on a 412 px wide viewport, including Mandarin.
7. If Heroku is authenticated: deploy with `scripts/deploy-heroku.ps1`, then repeat the click-through against https://resilience.chrisccluk.live and confirm `healthz` returns 200, `/v1/ai/*` returns 401 without a key and a real answer (`degraded:false`) with one.

Keep a running log in `docs/OVERNIGHT_LOG.md`: what you did, commands run, what failed, how you fixed it. Commit small and often on `kiro/overnight` with clear messages.

## Definition of done

All of these are true and you have evidence for each in the final report:
- `flutter analyze` clean; every Flutter, cloud and node test passes; new tests exist for every new rule and every abuse case.
- Items A to F work end to end in the browser click-through, including the two-profile scenarios, with zero console errors.
- No screen or button claims a capability that is not wired; the README "What works today" table, `docs/KIRO_HANDOFF.md` and the spec status labels are updated to match reality.
- `docs/DECISIONS.md` lists every judgement call you made.
- The branch is pushed, a PR to `main` is open with a description of the changes and the test evidence, and it is **not merged**.

## Final report (put this at the top of `docs/OVERNIGHT_LOG.md` and in the PR description)

1. One paragraph: what is done and what is not.
2. A table: feature, state (works / partial / not done), how you verified it, evidence (test name or screenshot path).
3. Anything you could not do and exactly why (permissions, missing credentials, platform limits).
4. Exact steps for the human to test in the morning: URLs, which two profiles/devices to use, what to click, what they should see.
5. Known risks and the next three things you would do.

Be honest in the report. A short list of things that really work is worth more than a long list that mostly works.
