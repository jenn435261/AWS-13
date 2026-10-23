# Resilience Network

**A local-first, encrypted, disruption-tolerant emergency coordination network.**
Communities discover resources, communicate, organize supplies, and physically
deliver aid even when conventional infrastructure is unavailable — starting from
the assumption that a user may be completely isolated, and progressively gaining
capability as nearby people, community nodes, LoRa links, the Internet, and
cloud infrastructure become available.

Built for the SJSU AI Hackathon (Oct 2026). AI is powered by **Amazon Bedrock**.

Team: Chris Luk, Shruti Nath, Jennelle Dabu, Bryan Cruz.

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
cd app && flutter pub get && flutter test            # 103 tests

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
deterministic rules engine (`degraded:true`). See `infra/DEPLOY_NOTES.md` and
`cloud/DEPLOY_HEROKU.md` for deployment.

## Status

Offline foundation, two-phone sync (convergence proven), community trust, secure
messaging, logistics, optional cloud (Bedrock-validated), the node daemon, and a
complete map-first UI are implemented and tested. See the PR for the full
breakdown.
