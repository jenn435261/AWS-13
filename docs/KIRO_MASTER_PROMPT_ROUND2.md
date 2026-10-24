# Master prompt for Kiro, round 2 (paste everything below the line)

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
- Work on a new branch off `feature/provider-map-supplies` (it already contains the `kiro/overnight` work), named `kiro/round2`. **Do not push to or force-push `main`, do not merge any PR, do not delete branches you did not create.** Open a PR at the end and leave it for the human.
- Do not run `heroku` destructive commands (no `apps:destroy`, no config var deletion, no DB resets). A deploy with `scripts/deploy-heroku.ps1` is allowed only if the Heroku CLI is already authenticated on this machine; otherwise skip deploy and say so in the report.
- Do not kill processes you did not start. Do not disable tests, skip tests, loosen assertions or add `--no-verify` to make things pass. A failing test means fix the code or the test's real mistake, and explain which.
- Do not add dependencies that break the Flutter web build. Known bad: `maplibre_gl`. `flutter build web --wasm` is expected to fail; use the JS build.

## Where things stand

Round 1 (`kiro/overnight`) is merged: app-side sync, encrypted messaging with photo/audio, location sharing, provider tools, raster PMTiles map from a node, signed package manifests, CORS. Read the final report at the top of `docs/OVERNIGHT_LOG.md` for what is honestly still missing. The human tested the live site and gave the field feedback below. Do all of it, in any order. Everything the human wants is listed; do not drop items because they are hard, mark them partial with exact reasons instead.

Overrides for this round: your branch is `kiro/round2` and you open a PR into `feature/provider-map-supplies` (do not merge it). The human deploys with `scripts/deploy-heroku.ps1` after the PR; deploy yourself only if the Heroku CLI is already authenticated, and never touch `infra/`.

## The work

## 1. Offline, connectivity and refresh (web + native)

1. **Real connectivity indicator.** The "online and ready" banner never changes when the network drops. Drive it from actual reachability: browser `online`/`offline` events (web), `connectivity_plus` (native), plus the result of the last sync/health attempt. States: Online / Cloud unreachable / Offline (local data only) / Node connected. Update live without reload.
2. **Service worker / offline app shell.** Safari shows "can't open page" on refresh offline. Ship a service worker (Flutter's `flutter_service_worker.js` caching, or a hand-written cache-first shell for the build output incl. `sqlite3.wasm`, `drift_worker.js`, `canvaskit`, fonts, `app-config.json` network-first with cache fallback). The app must cold-start offline from cache and load the local Drift DB. Test in a browser with network blocked and document the result. Confirm the cloud serves the correct headers (no `no-store` on the shell).
3. **Map refresh button** (map screen, bottom area, 48px+). Re-folds local state, triggers a cloud/node sync if reachable, re-centres on the last known position. Show last-refreshed time.
4. **Map must reflect supply status changes** (e.g. bottled water -> out of stock) immediately after the local write and after sync, without a reload. Find why the map provider is not invalidated by the fold; add a regression test.

## 2. Location without GPS

1. **Auto location.** Do not require tapping the locate button. On start/foreground, resolve position automatically (permission permitting), cache the last good fix (lat, lon, accuracy, timestamp) in KeyValue, and use it immediately as the map centre and as the default position for new requests/supplies while a fresh fix is pending. Mark it clearly as "last known, <age>".
2. **Manual pin.** When GPS/location services are off, denied, or timed out: long-press / "Set location manually" lets the user drop a pin on the (cached or online) map and also type coordinates or search a place name from the downloaded region. The pinned location is used everywhere the GPS fix is, flagged `manual`, and is included in events with a `location_source` of gps | last_known | manual (add to proto if needed, regenerate with buf, keep node+cloud+app in sync).
3. **Estimated position from last good fix.** On native, dead-reckon from the last good fix using step/heading sensors (`sensors_plus`, pedometer/accelerometer + magnetometer) with an uncertainty radius that grows with distance/time; show it as a translucent circle labelled "estimated". Never present it as GPS; user can accept it as their manual position. Web: not available, say so honestly.
4. Edit/update: every pin (request, supply, my location) can be moved later through an update event, not just created.

## 3. Supplies, forms and feedback

1. **Multi-select supplies.** Add-supply and offer flows use multi-select chips for category and items (water, food, medical, shelter, power, fuel, transport, hygiene, comms, tools, baby, pets, other) plus free text, quantity per item, and unit. One event per item or a list field; fold must handle both. Same for the request form (needs).
2. **Confirm closes the sheet.** Confirm/Save/Submit actions must close the bottom sheet or dialog, show a 5 s toast with Undo where it makes sense, and return focus to the list. Provide an obvious Edit/Update path for anything the user created (stock status, quantity, hours, location) and a Close/Cancel path that records a signed closing event.
3. **Haptics.** Light impact on taps/selection, medium on confirm, heavy/success pattern on SOS sent and request matched, error pattern on failures. Gate with a Settings toggle (default on). Web: `navigator.vibrate` where supported, otherwise silently skip.
4. **Optional identity.** Settings > Identity: optional display name, optional organisation/role (free text, never auto-verified), optional phone/contact note. Shown to contacts you choose; included in the identity QR card only if the user toggles "include name". Anonymous remains the default.

## 4. Contacts: My Resilience ID hidden + biometric lock

`local_auth` is a dependency but is never called. Hide the My Resilience ID / identity QR by default behind a "Reveal" button. If biometrics or device credentials are available (native), require `local_auth` to reveal and to export keys; on web or unsupported devices fall back to an explicit confirm plus a warning, and say plainly in the UI that no biometric is available. Auto-hide again after 30 s or when backgrounded. Settings toggle "Require unlock to show ID / open messages". Never store the unlock state persistently. Test the logic with a fake authenticator; mark device behaviour as "needs real device" in the docs.

## 5. Proactive alerts + downloads straight from the cloud

The app must learn that something bad MIGHT be coming while it still has internet, then pre-load everything useful.

1. **Cloud alert feed.** Add to `cloud/`: an ingest job (Heroku Scheduler / worker `cmd/worker`) pulling public feeds into signed-by-the-cloud-service `ALERT` events with a distinct `source = official_feed`: NWS/NOAA CAP alerts (`api.weather.gov/alerts/active?point=` / by area), USGS earthquakes, NASA FIRMS or NIFC wildfire perimeters, FEMA OpenFEMA declarations, GDACS (global). Keep it a pluggable `Feed` interface with fixtures for tests (no live network in tests). Severity, area polygon, onset/expires, instructions. Add `GET /v1/alerts?lat=&lon=&radius_km=&since=` and include them in `/v1/events/pull`. The cloud's feed key is a trusted root so clients show them as "Official" and not "community".
2. **Recommend where to go.** Server endpoint `GET /v1/safe-places?lat=&lon=&hazard=` returns ranked shelters/supplies/hospitals/high ground combining: verified supply providers in the event store, open shelters from the feeds (FEMA/Red Cross open data where available), and a Bedrock summary with rules fallback (existing `internal/ai`) that explains the recommendation in plain language and in the user's language. Never fabricate places; every result cites its source and age.
3. **Client pickup.** When online (foreground, and background on native via `workmanager`/BG fetch), poll the alert feed for the user's current/home/saved regions. New severe alerts raise a local notification and an in-app banner with a "Prepare now" button. Web: poll while open, use the Notifications API if permitted, optional Web Push (VAPID) if feasible; otherwise state the limit.
4. **Prepare now = download everything relevant** straight from the cloud even without a node: the region's map tiles (PMTiles via a cloud `GET /v1/packages` / `/v1/packages/{id}` endpoint with Range support, or an OSM-compatible tile bundle for the bbox with a size cap and consent screen showing MB), recent events in the radius, safe places, supplies, shelter list, first-aid/guidance content. Store on the client (Drift/IndexedDB/OPFS on web, files on native). Same signed-manifest verification as node packages; the cloud signs its own manifest.
5. **Never lose partial data.** Downloads are resumable and chunked; keep every verified chunk. A cancelled or failed download leaves what was fetched usable (partial regions render what exists) and shows "62% of Downtown pack, resume". New downloads merge/update, they do not delete older data until the replacement verifies. Retention rules and a storage screen with per-pack size and delete.
6. Offline downloads screen: sources become "Cloud" and "Node"; prefer node on local network, cloud otherwise, show which. Fill in the answer to "how do I download the offline map" in the UI with a clear first-run prompt and in the docs.

## 6. Android <-> iPhone transfer, Bluetooth, LoRA

Constraints already known: Wi-Fi Direct (Android) and Multipeer (Apple) are incompatible, so `nearby_transport.dart` only links same-family devices. Build the cross-platform paths:

1. **Animated QR transfer (air-gapped, any phone to any phone).** Implement high-speed animated QR: chunk a payload (event bundle, identity card, small package) with a fountain/erasure code (LT or RaptorQ-style) or sequence numbers + CRC so frames can be received in any order and lost frames are tolerated; 8-15 fps, QR version/ECC chosen adaptively; sender shows the animation (`qr_flutter`), receiver scans continuously (`mobile_scanner`) with progress ("212/340 frames"), verifies a final SHA-256 and the event signatures, then ingests through `EventStore.apply`. Evaluate and, if licence-compatible, borrow ideas from existing projects (e.g. TXQR, qrstream, "cimbar" colour-QR for higher throughput) but implement in Dart with tests (encode -> drop 30% frames -> decode round trip). Expose in Contacts/Network as "Transfer by QR". Document realistic throughput (a few KB/s) and what size it suits (events and identities, not map packs).
2. **BLE GATT transport (works Android <-> iOS).** New `Transport` implementation on `flutter_blue_plus` (central) plus a peripheral side (`flutter_ble_peripheral` / `bluetooth_low_energy`) with a custom service UUID, MTU-aware chunking, a short pairing step (compare 6-digit code or scan the QR identity card) and the existing signed-event sync (`have`/`push`/`pull` frames) on top. Encrypt per-session with keys derived from the contacts' identity keys. Keep it behind the existing `Transport`/`PeerSession` abstraction; test with the in-memory transport and a fake chunker; mark radio behaviour "needs real devices" honestly. Add the iOS Info.plist and Android manifest permissions.
3. **LoRA (Meshtastic).** Add a `LoraTransport`: bridge to a Meshtastic radio over BLE (and serial/USB on Android/desktop) using the Meshtastic protobufs (`meshtastic/protobufs`, port num `PRIVATE_APP` or a dedicated one). Constraints: ~200-230 byte payload, a few bytes/sec, duty-cycle limits, so send only compact signed events (SOS, request, supply status, alert ACK, location pings) as a binary-compressed envelope with fragmentation/reassembly and dedupe by event id; never photos/audio. Add a node-side LoRa gateway option: the Go node reads a Meshtastic device over serial (`/dev/ttyUSB*`, `go.bug.st/serial`), ingests received events (verify -> store) and broadcasts new SOS/alerts out, so a node bridges the LoRa mesh to the internet. Document hardware (Heltec V3 / T-Beam / RAK4631 with Meshtastic firmware), region/frequency settings, channel key handling, and how a phone-without-internet reaches a node-with-internet through the mesh. Tests: fragmenter/reassembler, compact codec round-trip, node ingest of a canned serial byte stream. Mark radio behaviour "needs real hardware".
4. Update Network Status to show each transport (Cloud, Node, Nearby, BLE, QR, LoRA) with state: unavailable here / idle / connected / last activity. Honest labels only.

## 7. Documentation (Kiro writes it; the human will film from it)

1. `docs/NODE_SETUP.md`: how to set up a Resilience Node end to end (Raspberry Pi/laptop/Docker), install, env vars (`PACKAGES_TRUSTED_ROOT`, signing key generation, ports, TLS/LAN considerations, Chrome local-network permission note), adding map packs and building a signed manifest, pairing a phone by QR, running with no internet, attaching a LoRA radio, backup/restore, troubleshooting.
2. `docs/DEMO_ORG_SETUP.md`: how to create a demo trusted organisation: generate the org root key, certify a provider, issue a delegated cert (depth limit 2), what "verified" means in the UI, how to revoke, how to seed demo data (a script `scripts/seed-demo.*` that creates an org, two providers, supplies and an alert), and how the cloud feed key is trusted. Include screenshots paths to capture.
3. `docs/HOW_IT_WORKS.md`: one-page architecture + data flow diagram (Mermaid) covering signed events, sync paths, privacy model, the transport matrix (what works with internet / LAN only / nearby / BLE / QR / LoRA, Android vs iPhone), and an honest "works today vs needs real device vs not built" table.
4. `docs/VIDEO_GUIDE.md`: a 5-minute video script for teammates: timed outline (0:00-5:00), what to show on screen, exact click path, narration lines, demo accounts/steps, pitfalls to avoid on camera, a pre-flight checklist, and a list of the honest limitations to say out loud.

## Definition of done

Every section above implemented or honestly marked partial in `docs/OVERNIGHT_LOG.md` (new final report at the top, same format). All tests green, web build passes, l10n parity test passes, no new secrets, README "What works today" updated. Open a PR from `kiro/round2` into `feature/provider-map-supplies`; do not merge it.
