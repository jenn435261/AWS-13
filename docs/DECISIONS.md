# Decisions Log — Resilience Network overnight run

Every judgement call made during the overnight run (branch `kiro/overnight`) is recorded here with its rationale. Subsequent features append their own decisions below.

## 2026-10-24

### Certificate issuance depth limit = 2

A certificate chain originating from a trusted root may be at most **2 hops deep**. That is, a trusted root may issue to an intermediate authority, and that intermediate may issue to a leaf — but a leaf certificate may not itself act as an issuer beyond that depth.

- Source: spec section 8 open policy question (`docs/SPEC_PROVIDER_AND_FEATURES.md`), pre-specified for this run.
- Rationale: bounds trust propagation so a single compromised intermediate cannot mint arbitrarily long chains; keeps verification cost and the trust surface small for an offline-first network where roots are distributed out of band.
- Applies wherever certificate chains are validated (trust engine / trust roots). Chains deeper than 2 hops from a trusted root are rejected.

### FEAT-002 (Item A) — app-side cloud + node sync client

- **JSON on the wire (not protobuf).** Both the cloud API (`cloud/internal/api/server.go`) and the node sync server (`node/internal/syncserver/server.go`) content-negotiate protobuf-or-JSON. `CloudSync` sends `Content-Type: application/json` + `Accept: application/json` and serializes via `toProto3Json()`/`mergeFromProto3Json`. Rationale: JSON is the most portable choice, works identically on Flutter web (where `dart:ffi` protobuf quirks are a risk) and native, and keeps the request/response inspectable. Byte volume is not a concern at the batch sizes involved, and the content is already signed so there is no integrity loss.
- **One class, two endpoint kinds.** A single `CloudSync` class is parameterized by `SyncEndpointKind` (`cloud` → `/v1/events` + `/v1/events/pull`; `node` → `/node/v1/push` + `/node/v1/pull`) rather than two near-identical classes. The request/response proto types are shared by both servers, so this avoids duplication.
- **Cursor storage scheme.** Push high-water marks live in the existing `KeyValue` table via `JsonStore` under the `sync:` prefix, one row per endpoint keyed `pushhw:<kind>:<baseUrl>`. The **pull** side needs no stored cursor: the per-author high-water digest is derived live from `EventDao.highWaterByAuthor()`, so pulls are naturally incremental and idempotent. "N pending" = count of our own events (`eventsByAuthorFrom(myAuthor, pushHighWater)`).
- **Ingestion path.** Every pulled event is applied through `EventStore.applyAll` → `EventStore.apply`, the single verify-then-store path, so a forged/tampered event fails `EventFactory.verifyEvent` and is never stored (proven by `app/test/cloud_sync_test.dart` and the Go `TestServerPushVerifiesAndPulls`). After a round that applied anything new, `bumpWorldRef(ref)` recomputes the folded `WorldState`.
- **Backoff policy.** Exponential backoff starting at 1s, doubling, capped at 2 minutes; reset to zero on a clean round. A 30s periodic timer drives syncs while the app is visible; sync also fires on start, on `AppLifecycleState.resumed`, and after every local write (observed via `worldRevisionProvider`). Concurrent rounds are coalesced (a `_running` guard) so overlapping triggers do not stack.
- **Honest failure.** `syncOnce()` never throws: timeouts (10s on every HTTP call) and non-200 responses are captured in `SyncOutcome.error` and surfaced as a truthful message on the Network Status screen. No active node saved ⇒ node sync is a no-op, not an error.
- **Two-profile scenario: Go-level substitute, not a browser run.** The browser two-profile click-through was NOT run (see OVERNIGHT_LOG for the reason). It was substituted with `TestTwoProfileSyncThroughCloud` in `cloud/internal/api/server_test.go`, which runs a real local cloud API (`httptest`) and two distinct Ed25519 identities: profile A publishes a help request, a supply, an emergency alert and an identity certificate; profile B pulls from an empty watermark and receives all four byte-identical (so the verified/community provenance in the body is preserved), then a re-pull from the new watermark returns nothing (idempotence).
