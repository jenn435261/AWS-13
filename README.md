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
cd app && flutter pub get && flutter test            # 107 tests (excluding screenshots_test, which needs the original author's sandbox font path)

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

## What works today (verified by clicking through the web build)

| Area | State |
|------|-------|
| Signed event log, local DB (SQLite-WASM on web, SQLite on mobile) | Working. "I Need Help"/"Offer Help" create signed events, persisted locally; My Requests / My Supplies read them back |
| Contacts | Working: add by QR scan (camera), by pasted code, show/copy my QR; saved locally; remove with undo |
| AI assist (Bedrock via the Go API) | Working when the API is reachable and AWS credentials are valid; otherwise local rules (`degraded`) |
| Network status | Real: probes the cloud `/healthz` (latency, last checked). Nearby peers unavailable in browsers; node and LoRa not set up |
| Offline downloads | Probes a Resilience Node address you enter and lists only what it confirms |
| Trusted organizations | Shows installed trust roots (empty until a readiness package installs one) |
| Data controls | Erase-all really wipes events, contacts and identity; clear-cache rebuilds derived state |
| Location sharing | **Not connected.** Audience/precision/duration (15m, 1h, 4h, 24h, until I stop) UI exists, but there is no position source or delivery path, so the button is disabled |
| Secure messaging | **Not connected.** Crypto engines are tested (Signal X3DH/Double Ratchet), but chats need prekey publication, a durable Signal store and an app-side sync client that do not exist yet |
| App-side cloud sync (push/pull events) | **Not built.** The API endpoints exist and are tested; the app does not call them yet |
| Cloud event store | In-memory on the Heroku dyno (resets on restart) unless `RESILIENCE_PG_DSN` is set |

## Status

Offline foundation, two-phone sync (convergence proven), community trust, secure
messaging, logistics, optional cloud (Bedrock-validated), the node daemon, and a
complete map-first UI are implemented and tested. See the PR for the full
breakdown.
