# Proactive alerts + offline downloads (Round 2 §5 / FEAT-004)

This document explains the public-feed ingest, the alert/safe-places/packages
endpoints, how clients learn the trusted feed key, how "Prepare now" downloads
work, and the exact (unrun) Heroku commands for the feed signing key and the
scheduled ingest. No secrets are committed; the signing key lives only in env /
Heroku config vars.

## How it works (data flow)

```
public feeds (NWS/NOAA CAP, USGS, NIFC/FIRMS wildfire, FEMA OpenFEMA, GDACS)
        │  (cloud/cmd/feedworker fetches on a schedule)
        ▼
feeds.Feed adapters  ──Parse(raw)──▶  AlertRecord (normalized)
        │
        ▼
feeds.Ingestor.SignAll  ──signs with the CLOUD FEED KEY──▶  EMERGENCY_ALERT events
        │   (alert_id = feed:<source>:<native-id>; detail prefixed [official_feed:<source>])
        ▼
store.Push  (verify-before-store)  ──▶  authoritative event store
        │
        ├──▶ GET /v1/alerts?lat=&lon=&radius_km=&since=   (scoped, geo/freshness filtered)
        └──▶ GET /v1/events/pull                          (ordinary sync picks them up)
                                   │
                                   ▼
             app: EventStore.apply verifies the signature before storing;
             an alert signed by the TRUSTED FEED ROOT renders as "Official".
```

### source=official_feed without a proto change

The feed source is encoded inside the existing `EmergencyAlertBody` (no proto
change): the `alert_id` is `feed:<source>:<native-id>` and the `detail` begins
with a marker line `[official_feed:<source>]`. `feeds.IsFeed` / `feeds.SourceOf`
parse it back; the app strips the marker for display.

### Trusted feed root (how the app labels alerts "Official")

The feed signing key's PUBLIC half is advertised to clients:

- Web: the cloud API returns it in `/app-config.json` as `feedPubkey` (and in
  `/v1/alerts` as `feed_pubkey`). The web app reads it at startup.
- Native: pass `--dart-define=FEED_PUBKEY=<hex>` at build time.

The app verifies an `EMERGENCY_ALERT` signature against this root to show it as
Official (verified), not community. With no key configured the app shows an
honest unverified state and `/v1/alerts` returns an empty set (never fabricated).

## "Prepare now" + offline downloads

`GET /v1/packages` / `GET /v1/packages/{id}` serve PMTiles map packs with HTTP
Range (206), plus `GET /v1/packages/manifest` — a cloud-signed manifest
(detached Ed25519 over canonical compact JSON, per-file SHA-256). This MIRRORS
the node's signed-manifest flow, so the app reuses ONE verifier
(`app/lib/nodes/package_manifest.dart`); the cloud just signs with its own
`CLOUD_PACKAGES_SIGNING_KEY` (a distinct trusted root, advertised as
`feedPubkey` for the cloud path).

"Prepare now" (app): resolve the source (node on LAN else cloud), fetch+verify
the manifest, show the download size + a 250 MB cap with an explicit MB consent
screen, then download the map pack(s) resumably (chunked, keeps every verified
chunk, resumes, shows `N% of <region>, resume`), verifying each file's SHA-256
against the signed manifest before trusting it. Partial downloads render what
exists; a new download never deletes the prior verified pack until the
replacement verifies. The Storage screen shows per-pack size + delete.

### Honest limits (not faked)

- Web Push/VAPID (notifications when the tab is closed) is NOT implemented
  (needs a service-worker push subscription + a server push endpoint). The web
  Notifications API is used only while the tab is open and only with permission.
- Native local notifications + native background polling need
  `flutter_local_notifications` / workmanager + a real device; the in-app banner
  covers the open-app case on every platform.
- On web there is no plain filesystem; "survives a reload" means IndexedDB/OPFS
  (Drift), not an OS file. A true background download with the tab closed is not
  possible on web.

## Heroku deploy (commands documented, NOT run here)

The Heroku CLI is not authenticated in this environment, so these are written
for the operator to run. Generate a feed key pair once (keep the private key
secret), then set config vars. Example key generation (Go):

```sh
# Print a hex seed (32 bytes) you can use as FEED_SIGNING_KEY, and its public
# hex for FEED_PUBKEY. (Run locally; never commit the output.)
go run ./cloud/cmd/feedworker -h   # (the worker logs feed_pubkey at boot)
```

Set the API dyno's public feed key + optional cloud packages dir/key:

```sh
heroku config:set FEED_PUBKEY=<hex public key> -a <app>
heroku config:set CLOUD_PACKAGES_DIR=/app/packs -a <app>
heroku config:set CLOUD_PACKAGES_SIGNING_KEY=<hex private key or seed> -a <app>
```

Set the feed worker's PRIVATE signing key + tuning:

```sh
heroku config:set FEED_SIGNING_KEY=<hex private key or seed> -a <app>
heroku config:set FEED_INGEST_INTERVAL=15m -a <app>
heroku config:set FEED_TTL=6h -a <app>
```

Run the ingest on a schedule with the Heroku Scheduler add-on (one-shot pass):

```sh
heroku addons:create scheduler:standard -a <app>
# In the Scheduler dashboard, add a job (e.g. every 10 minutes):
#   FEED_RUN_ONCE=1 go run ./cloud/cmd/feedworker
# or run the built binary with FEED_RUN_ONCE=1.
```

Alternatively run the feed worker as a long-lived worker dyno (Procfile):

```
feedworker: ./bin/feedworker
```

Postgres (so alerts persist across dyno restarts) is shared with the api/worker
via `RESILIENCE_PG_DSN` (already provisioned per the existing deploy docs).
