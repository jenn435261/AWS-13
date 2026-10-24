# Demo trusted organisation setup

This walks through creating a demo **trusted organisation**, certifying
providers, understanding the certificate depth limit, what "verified" means in
the UI, how to revoke, and how to seed a self-consistent set of demo data with
the runnable `scripts/seed-demo.sh`. It also explains how the cloud feed key
(FEAT-004) is trusted. Rule that holds throughout: nothing here fabricates
trust - every certificate and every demo event is a real Ed25519-signed event
that the fold/store verifies before accepting.

## 1. Trust model in one paragraph

An organisation is identified by its **root key** (an Ed25519 keypair). The
root certifies a subject (a provider, a facility, a person) with a signed
`ORG_CERTIFICATE` event carrying `org_root_pubkey`, `subject_pubkey`,
`provenance = VERIFIED_ORG`, and a validity window. A certified subject may
itself certify others, forming a chain. The app grants the **verified** badge
to a key reachable from a trusted root within the certificate **depth limit of
2** (see §4). Trust is distributed out of band: an operator installs a root's
**public** key in the app as a trusted org; the app never auto-trusts a key.

## 2. Create the org root key

The root key is an ordinary Ed25519 keypair. Two equivalent ways:

- **In the app:** found an organisation from your own identity (the app uses
  your key as the org root) and add it under **Trusted organisations**. Share
  your public key so others can trust you.
- **Headless (for the demo seed):** `scripts/seed-demo.sh` generates a root key
  in memory and prints its **public** hex. You install that hex as a trusted
  org in the app. Pass `--seed <hex32>` for a deterministic root across runs.

The private half never leaves memory and is never printed or committed.

## 3. Certify a provider

A certification is a signed `ORG_CERTIFICATE` from the root (or an intermediate)
naming the subject, with `provenance = VERIFIED_ORG` and a validity window. In
the app a root certifies a saved contact from the provider screen ("certify
contact"). Headless, the seed script emits these events directly (see §6).

## 4. Delegated certificate, depth limit 2

A certificate chain from a trusted root may be at most **2 hops deep** (see
`docs/DECISIONS.md`, "Certificate issuance depth limit = 2", enforced in
`OrgCertGraph.provenanceOf`, `app/lib/trust/org_certs.dart`):

- depth 0: the root (certifies itself);
- depth 1: a key the root certifies **directly** -> verified;
- depth 2: a key certified by a depth-1 key -> verified (the maximum);
- depth 3+: **not** granted the badge.

The breadth-first walk means the **shortest** chain to a root decides, revoked
keys break a path, and cycles are defeated by a visited set. The demo seed
deliberately creates one provider at depth 1 and one at depth 2 so you can see
both verify, and (optionally) a depth-3 key to see it stay community.

## 5. What "verified" means in the UI

- A supply, shelter or alert authored by a verified key shows the **verified**
  (checkmark) provenance; a community key shows the **community** (circle)
  state. The provider screen's status card says whether you are verified and
  why (which root, how many hops).
- Only verified providers may publish verified supplies, post emergency alerts
  (and recall their own), and create/assign missions; a non-verified key's
  attempt is ignored by the fold (abuse rule), not shown as if it worked.
- Verified status is **never** auto-granted and never implied: with no trusted
  root installed, everything is community, honestly.

## 6. Seed demo data: `scripts/seed-demo.sh`

The script builds a small, self-consistent set of **signed** events and
re-verifies each one locally before printing or pushing. It is backed by
`cloud/cmd/seed-demo/main.go` (Go is the most reliable toolchain here).

What it creates:

- an **org root** identity (prints its public key to install as a trusted org);
- **provider A**, certified directly by the root (`ORG_CERTIFICATE`, depth 1);
- **provider B**, certified by provider A (`ORG_CERTIFICATE`, depth 2 - the
  maximum);
- **two verified supplies** (water from A, first-aid from B);
- **one emergency alert** signed by provider A.

### Run it (smoke: build + verify locally)

```sh
./scripts/seed-demo.sh
```

Expected output (keys differ per run unless you pass `--seed`):

```
demo org seed - built and locally verified 6 signed events
  org root PUBLIC key (install as a trusted org in the app):
     <64 hex chars>
  provider A (depth 1, verified): <hex>
  provider B (depth 2, verified): <hex>
  - EVENT_TYPE_ORG_CERTIFICATE       id=...
  - EVENT_TYPE_ORG_CERTIFICATE       id=...
  - EVENT_TYPE_ORG_CERTIFICATE       id=...
  - EVENT_TYPE_RESOURCE_CREATED      id=...
  - EVENT_TYPE_RESOURCE_CREATED      id=...
  - EVENT_TYPE_EMERGENCY_ALERT       id=...
  no -cloud URL given: build+verify only (smoke OK). ...
```

Every event is re-checked with `events.VerifyEvent`; a build/verify failure
exits non-zero. This is the smoke step - if it prints the six events it works.

### Push to a running cloud API

```sh
# Start a local cloud API first (see docs/OVERNIGHT_LOG.md morning steps), then:
./scripts/seed-demo.sh --cloud http://localhost:8187 --key devkey
```

It JSON-encodes a `PushEventsRequest` and POSTs to `/v1/events`; the store
applies verify-before-store, so a tampered event would be rejected, not stored.
A deterministic root for repeatable demos:

```sh
./scripts/seed-demo.sh --seed 00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff
```

### Make the demo show as verified

Install the printed **org root public key** in the app under **Trusted
organisations**. Pull the seeded events (cloud or node sync). The two supplies
and the alert now render as **verified** because their authors chain to the
trusted root within depth 2. Without installing the root, they show honestly as
community - the script never forces a badge.

## 7. Revoke a key (`KEY_REVOKED`)

Revocation is a signed `KEY_REVOKED` event naming the `revoked_pubkey` and a
reason. In the fold, a revoked key on a certificate path breaks that path, so a
previously-verified subject loses the badge (unless another valid shorter chain
exists). Revocation is itself a signed event, so it propagates over the same
sync/mesh paths as everything else. (The seed script does not revoke anything;
add a `KEY_REVOKED` event the same way the certs are built if you want to
demonstrate it.)

## 8. How the cloud feed key is trusted (FEAT-004)

Official alerts from public feeds (NWS/NOAA CAP, USGS, wildfire, FEMA, GDACS)
are signed by a dedicated **cloud feed key** and marked `source=official_feed`
(encoded in the alert body, no proto change - see `docs/FEED_AND_DOWNLOADS.md`).
The app labels such an alert **Official** only when it verifies against the feed
root:

- **Web:** the cloud returns the feed public key in `/app-config.json` as
  `feedPubkey` (and in `/v1/alerts` as `feed_pubkey`); the web app reads it at
  startup.
- **Native:** pass `--dart-define=FEED_PUBKEY=<hex>` at build time.

With no feed key configured, the app shows an honest unverified state and
`/v1/alerts` returns an empty set - never a fabricated official alert. The feed
**private** key lives only in a Heroku config var (`FEED_SIGNING_KEY`), never in
git.

## 9. Screenshots to capture (for the demo/video)

Capture these into `docs/screenshots/` (create the folder) when you do the live
click-through:

- `demo-trusted-orgs.png` - Trusted organisations with the demo root installed.
- `demo-provider-verified.png` - the provider status card showing verified +
  which root/hops.
- `demo-supply-verified.png` - a seeded supply on the map with the verified
  (checkmark) provenance.
- `demo-alert-official.png` - the seeded/official alert banner, honestly labelled.
- `demo-revoke.png` - a key after `KEY_REVOKED` losing its badge (optional).

These are capture targets for the human; they are not committed by this run.
