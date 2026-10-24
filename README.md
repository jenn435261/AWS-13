# Resilience Network

**A local-first, encrypted, disruption-tolerant emergency coordination network.**
Communities discover resources, communicate, organize supplies, and physically
deliver aid even when conventional infrastructure is unavailable — starting from
the assumption that a user may be completely isolated, and progressively gaining
capability as nearby people, community nodes, LoRa links, the Internet, and
cloud infrastructure become available.

Built for the SJSU AI Hackathon (Oct 2026). AI is powered by **Amazon Bedrock**.

Team: Chris Luk, Shruti Nath, Jennelle Dabu, Bryan Cruz, Nathan Taladua.

## Why it's different

The phone is the primary computer, not the cloud. Everything is created locally,
signed, shown immediately, and *then* distributed opportunistically over whatever
transport exists. No connection is required for the app to work; each additional
connection only improves synchronization.

- **Local-first + offline-first.** Create resources, requests, offers, and
  messages with zero connectivity; they sync when a peer, node, LoRa link, or
  the Internet appears.
- **Signed, immutable event log.** Every action is a content-addressed
  (BLAKE2b-256) + Lamport/DAG-ordered, Ed25519-signed event. State is derived by
  folding the log, so independent devices converge even with wrong clocks.
- **End-to-end encryption.** Direct and group messaging use the Signal Protocol
  (X3DH + Double Ratchet + Sender-Key groups). Relays carry opaque ciphertext.
- **Three-dimensional trust.** Source (verified org vs community), corroboration
  (confirm/dispute by distinct observers), and freshness (visible decay) — never
  a single score. Low-confidence info ranks lower but never disappears.
- **Capability-based authorization.** A mission driver capability grants exactly
  that mission's rights (see exact pickup, confirm handoff) — not blanket trust.
- **Privacy-first location sharing.** Opt-in, audience-scoped, time-boxed,
  revocable, E2E-encrypted — designed to be safe even when authorities may be
  hostile (civil-unrest scenarios), with aggregate-only data for organizations.
- **AI assist (Amazon Bedrock), optional.** Freeform report → structured event,
  translation, summarization, duplicate detection — with a deterministic offline
  fallback so the core system always works without AI.

## Repository layout

| Path | What |
|------|------|
| `proto/` | Protobuf event + sync schema (source of truth; codegen for Dart + Go) |
| `app/`   | Flutter app (Riverpod, Drift/SQLite, MapLibre/PMTiles, Signal, nearby_service). Map-first UI, i18n EN/ES, accessibility, biometric lock. |
| `cloud/` | Go authoritative cloud: verify-before-store event store, sync API, Bedrock AI endpoints, aggregate org API. ECS/Lambda/Heroku deployable. |
| `node/`  | Go Resilience Node daemon: local event cache + sync server + offline web app + APK/map/package server + cloud/mesh gateway. |
| `infra/` | AWS CDK (us-east-1): S3 + Bedrock-enabled API Lambda (+ optional RDS/PostGIS/SQS). |

## Build & test

Toolchain: Flutter (Dart 3.11+), Go 1.26, protoc/buf.

```bash
# App
cd app && flutter pub get && flutter test $(ls test/*.dart | grep -v screenshots_test.dart)   # 266 tests (screenshots_test excluded: hard-coded sandbox font path)

# Cloud (Go)
cd cloud && go test ./...                            # events/store/api/ai/org

# Node (Go, self-contained module)
cd node && go test ./...

# Regenerate protobuf (if proto/ changes)
cd proto && buf generate
```

## AWS / Amazon Bedrock

Bedrock inference is proven live in us-east-1 via the Claude Sonnet 4.5 inference
profile. The Go API exposes `/v1/ai/{structure,translate,summarize,dedup}`; with
`BEDROCK_MODEL_ID` set it calls Bedrock, otherwise it falls back to the
deterministic rules engine (`degraded:true`).

## Live deployment (Heroku + Bedrock)

The Go API **and the Flutter web app** are served by one Heroku container app
(`resilience-api-chris`); the API calls Amazon Bedrock with AWS credentials held
as Heroku config vars. The web app is the same Flutter code as the mobile app,
so it runs in any browser (local-first via Drift/SQLite-WASM + IndexedDB).

- Web app + API: https://resilience.chrisccluk.live (also
  `https://resilience-api-chris-83ac9d67094f.herokuapp.com`)
- Health: `/healthz`. AI: `POST /v1/ai/structure` etc.

| Config var | Purpose |
|------------|---------|
| `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | Bedrock credentials (event STS creds expire at event end) |
| `BEDROCK_MODEL_ID` | `us.anthropic.claude-sonnet-4-5-20250929-v1:0` |
| `CLIENT_API_KEYS` | Comma-separated keys; gates `/v1/events`, `/v1/events/pull`, `/v1/ai/*` (401 without `X-Api-Key`). Abuse guard, not user auth: the web app receives the first key from `/app-config.json`. |
| `ORG_API_TOKENS` | Gates `/v1/org/needs` (`X-Org-Token`) |
| `WEB_DIR` | Set in the Dockerfile; serves the Flutter web bundle |

Deploy (builds the web app, ships API + bundle):

```powershell
./scripts/deploy-heroku.ps1
```

Native builds target the same backend: `flutter build apk --dart-define=CLOUD_API_KEY=<key>`
(`CLOUD_BASE_URL` defaults to `https://resilience.chrisccluk.live`; set it empty for fully offline).

### Custom domain (Cloudflare)

`heroku domains:add resilience.chrisccluk.live -a resilience-api-chris` prints a
DNS target. In Cloudflare DNS add a `CNAME` record: name `resilience`, target =
that Heroku DNS target, **Proxy status: DNS only** (grey cloud) until Heroku ACM
issues the certificate (`heroku certs:auto -a resilience-api-chris`); afterwards
the proxy may be enabled with SSL/TLS mode **Full**.

### Why not Lambda/CDK?

`infra/` is a complete CDK app (S3 + Bedrock-enabled Go Lambda), but the hackathon
event account (`WSParticipantRole`) denies `iam:CreateRole`/`PassRole`, so
`cdk bootstrap` fails (re-confirmed). It deploys on any normal AWS account
(`infra/deploy.sh`). See `infra/DEPLOY_NOTES.md`. S3 and Bedrock were proven live.

## What works today

Honest states below. **Working** = exercised by tests + the passing web build.
**Native-only** = works on device, honestly unavailable on web. **Needs real
device/hardware** = code + unit tests exist, but a radio/second device is
required and was not exercised here. **Not built** = deliberately absent.
Interaction-level UI driving is not possible headlessly in this sandbox (the
Flutter semantics tree publishes no aria-label nodes), so UI behaviour is proven
by Dart fold/abuse/widget tests + Go endpoint tests + a zero-console-error web
boot, not by clicking. See `docs/HOW_IT_WORKS.md` for the full transport matrix.

### Round 2 additions

| Area | State |
|------|-------|
| Connectivity indicator | Working: a live banner shows Online / Cloud unreachable / Node connected / Offline from `lib/sync/connectivity.dart` |
| Offline service-worker app shell | Working: a hand-written cache-first service worker (`app/web/sw.js`) + cacheable cloud headers (`cloud/internal/api/web.go`) serve the shell offline |
| Map refresh + fold-driven updates | Working: a refresh button and a fold-invalidation regression test (map updates when the world changes) |
| Auto / last-known location | Working: a last-known fix is cached and shown as "last known, <age>" when a live fix is unavailable |
| Manual pin | Working: drop a pin by hand; the point records `location_source = MANUAL` |
| Estimated (dead-reckoning) position | Native-only via `sensors_plus`; web is honestly unavailable |
| Multi-select supplies / needs | Working: pick multiple categories + items with qty/unit/free text, mapped to existing proto categories (no proto change) |
| Haptics | Working (native): gated helper + Settings toggle (default on); web has no haptics |
| Optional identity | Working: Settings > Identity, never auto-verified, include-name QR |
| Reveal-gated Resilience ID + biometric lock | Working: `local_auth` behind an authenticator interface (`FakeAuthenticator` in tests), 30s/background auto-hide, Settings "Require unlock" toggle |
| Cloud alert feed / official alerts | Working (server): pluggable ingest (NWS/NOAA CAP, USGS, wildfire, FEMA, GDACS) to signed `official_feed` alerts; `GET /v1/alerts`; feed alerts in `/v1/events/pull`. Worker gated on `FEED_SIGNING_KEY`. Feed fixtures + Go tests |
| Safe places | Working (server): `GET /v1/safe-places` returns sources + age, never fabricates, with a rules/Bedrock summary |
| Prepare-now downloads + resumable | Working (native best): consent download with a MB cap; resumable chunked download keeps verified chunks. Web has no persistent partial file (IndexedDB/OPFS only) |
| Cloud packages | Working: `GET /v1/packages` with a cloud-signed manifest + Range, mirroring the node; the app reuses one verifier |
| Animated QR transfer | Working (codec + verify): loss-tolerant fountain code, SHA-256 + signature verified, ingested via `EventStore.apply`, exposed as "Transfer by QR". On-camera scan needs a device |
| BLE GATT transport | Needs real device: MTU chunking, 6-digit pairing, AES-GCM session behind `flutter_blue_plus` (native-only, conditional import), Android/iOS permissions declared. Unit-tested; no radio here |
| LoRa transport + node gateway | Needs real hardware: <=222-byte envelope, fragmentation/dedupe, compact kinds only; node Go serial gateway (opt-in `--lora-serial-port`). Unit-tested from a canned stream; needs a Meshtastic radio |
| Network Status transport matrix | Working: honest per-transport labels (reachable / connected / idle / needs device / needs hardware / unavailable here) |
| Web Push / VAPID | Not built (needs a service-worker push subscription + a server push endpoint) |
| Native local notifications + background polling | Needs real device (needs a plugin + device); the in-app banner covers the open-app case |

### Round 1 foundation

| Area | State |
|------|-------|
| Signed event log, local DB (SQLite-WASM on web, SQLite on mobile) | Working. "I Need Help"/"Offer Help" create signed events, persisted locally; My Requests / My Supplies read them back |
| Contacts | Working: add by QR scan (camera), by pasted code, show/copy my QR; saved locally; remove with undo |
| AI assist (Bedrock via the Go API) | Working when the API is reachable and AWS credentials are valid; otherwise local rules (`degraded`). Surfaced in the UI: Home summary bar, a translate panel on notes / request details / incoming messages, and a non-blocking duplicate check before submitting a request. The original text is always kept and a degraded chip is shown honestly |
| Network status | Real: probes the cloud `/healthz` (latency, last checked) and shows live cloud/node sync status (last synced, pending count, errors). Nearby peers unavailable in browsers; LoRa not set up |
| Offline downloads | Pick a saved node, read its real package catalog, and keep your own library of package versions (add / edit / check / download / delete). When the node serves a **signed manifest** that verifies against your configured trusted root, downloads can be **checksum-verified** (SHA-256 against the signed manifest) before you trust them; otherwise the manifest state is shown honestly as unverified/unavailable |
| Trusted organizations | You choose which organization keys to trust (from a contact, or your own key when founding one); persisted; untrust any time |
| Map | Real OpenStreetMap map (pan/zoom, locate me). Requests, supplies and shelters plot at their true (rounded ~110 m) coordinates. Supplies past their "available until" time and closed requests are auto-hidden. Online tiles need internet; when the active node serves **offline PMTiles** (raster) they are used and an honest offline banner is shown, otherwise it falls back to the online OSM raster layer |
| Supplies | Full lifecycle: add (type, item, number + free-text unit, amount level, available now / today / until a date, location), edit, restock, mark out of stock, take down, put back up. Supplies past "available until" show as **Expired** and drop off the map. Only the owner's edits count |
| Requests | My Requests can **close/cancel** a request (owner-only; it leaves the map, the record stays verifiable). A close from any other key is ignored |
| Provider tools | Verified providers (a trusted root, or certified within **2 certificate hops** of one) can publish verified supplies, post emergency alerts (and **recall** their own alerts), and create + assign missions; roots can certify contacts. Community users see how to become one. Verified-org status requires a chain from a trusted root at most 2 hops deep |
| Deliveries / missions | Verified providers assign a carrier to a mission (`MISSION_MATCHED`, verified-only — a non-provider assignment is ignored); carriers accept a mission from the Deliveries tab (`MISSION_ACCEPTED`). Buckets: Assigned / Available / In transit / Awaiting handoff / Completed |
| Resilience nodes | Save several nodes (scan the node's QR or type an address), rename, set active, check reachability, delete |
| Languages | English, Spanish, French, Mandarin (Simplified) |
| Data controls | Erase-all really wipes events, contacts and identity; clear-cache rebuilds derived state |
| Location sharing | Working: the Share button takes a real position (opt-in, rounded ~110 m unless you pick exact), encrypts the point to the chosen contacts over the Signal E2E path, and is time-boxed (15m / 1h / 4h / 24h / until I stop) and revocable (Stop). Shares fold into the map/list and auto-expire; only the author can stop their own share |
| Secure messaging | Working end to end: durable Drift-backed Signal store (X3DH + Double Ratchet), prekey bundles published as signed events, text + photo (EXIF-stripped, re-encoded) + voice notes, AES-256-GCM attachments as content-addressed opaque blobs, delivery states. Relays/cloud only ever see ciphertext |
| App-side cloud + node sync (push/pull events) | Working: the app pushes unsent local events and pulls new ones from the cloud (`/v1/events`, `/v1/events/pull`) and from a node (`/node/v1/push`, `/node/v1/pull`), ingesting every pulled event through the verify-before-store path. Visible status, exponential backoff, honest offline handling |
| CORS | The cloud API sends CORS headers and answers OPTIONS preflight (incl. `X-Api-Key`), so the Flutter web app can call it from a different origin. Mirrors the node's CORS policy |
| Cloud event store | In-memory on the Heroku dyno (resets on restart) unless `RESILIENCE_PG_DSN` is set |

## Status

Offline foundation, two-phone sync (convergence proven), community trust, secure
messaging, logistics, optional cloud (Bedrock-validated), the node daemon, and a
complete map-first UI are implemented and tested. Round 2 added the connectivity
indicator, an offline service-worker shell, auto/last-known/manual/estimated
location, multi-select supplies, gated haptics, optional identity with a
reveal-gated biometric-locked Resilience ID, a cloud official-alert feed +
safe-places + resumable signed downloads, and QR/BLE/LoRa transports (BLE/LoRa
need real radios). See `docs/HOW_IT_WORKS.md` for the honest works-today vs
needs-real-device vs not-built breakdown, and `docs/OVERNIGHT_LOG.md` for the
Round-2 report.
