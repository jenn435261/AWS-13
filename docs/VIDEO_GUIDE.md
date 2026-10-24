# 5-minute video guide

A timed script for a 5-minute demo of Resilience Network. It shows only what
genuinely works, says the honest limits out loud, and keeps a tight click path.
Record in a real browser (the live site or a local build) and/or a native build
for the device-only features. Never claim something on camera that is not wired.

## Pre-flight checklist (do before recording)

- [ ] Stack running. Either the live site (if deployed) or a local build served
      same-origin through the cloud, plus a node with a signed manifest (see
      `docs/OVERNIGHT_LOG.md` morning steps for the exact commands).
- [ ] Two browser profiles open (Profile A and Profile B) at the app URL. Each
      reads the API key from `/app-config.json`.
- [ ] Demo org seeded: run `./scripts/seed-demo.sh` (smoke) or
      `./scripts/seed-demo.sh --cloud <url> --key <key>` to push, and install the
      printed **org root public key** in Trusted organisations so the demo shows
      verified. See `docs/DEMO_ORG_SETUP.md`.
- [ ] Geolocation permission granted to the map in both profiles.
- [ ] A node reachable with a `<region>.pmtiles` map pack so the offline map and
      signed-manifest flow can be shown. For web use an HTTPS node (mixed
      content blocks plain HTTP); otherwise demo the node flow on native.
- [ ] Language set to English (switching to Spanish/French/Mandarin is a nice
      5-second beat if time allows).
- [ ] Console open on one profile to show zero page errors (optional credibility
      beat).
- [ ] Phone with the native build ready **only if** you plan to show BLE/LoRa or
      estimated position - otherwise skip those and say so.

## Timed outline (0:00-5:00)

### 0:00-0:30 - Hook + premise

- **Show:** the map screen with a few seeded resources/alerts.
- **Narration:** "Resilience Network is a local-first emergency app. The phone
  is the primary computer, not the cloud. Everything you create is signed and
  shown instantly, then synced over whatever connection exists - internet, a
  local node, nearby phones, QR, or a LoRa mesh. No connection is required for
  it to work."

### 0:30-1:30 - Create and converge (two profiles)

- **Click path (Profile A):** tap **I Need Help** -> pick a category -> add a
  short note -> submit. Then as a provider, open the provider screen -> **Post
  alert** (or show the seeded official alert).
- **Click path (Profile B):** wait ~30s or tap **Refresh** in Network Status ->
  the request and alert appear.
- **Narration:** "Profile A creates a help request; it is a signed event stored
  locally first. Profile B pulls it through the cloud - or a local node with no
  internet - and every pulled event is verified before it is stored. State is a
  fold over the signed log, so independent phones converge."

### 1:30-2:30 - Trust, verified providers, privacy

- **Show:** the verified (checkmark) badge on the seeded supply; open Trusted
  organisations to show the installed demo root; open the provider status card
  (verified, which root, how many hops).
- **Show:** start a location share - pick an audience and a duration (15m / 1h /
  until I stop) - and point out the ~110 m rounding and the Stop control.
- **Narration:** "Trust is three-dimensional: source, corroboration, freshness - never one score. A verified provider chains to a root you installed, within
  two certificate hops. Location sharing is opt-in, rounded, time-boxed,
  revocable, and end-to-end encrypted to just the people you choose."

### 2:30-3:30 - Offline: node, map, signed downloads

- **Click path:** More -> Resilience nodes -> show the active node (or scan its
  pairing QR). Open the map and show it using the node's offline PMTiles with
  the honest offline banner. Then More -> Offline Downloads -> show the
  **verified** manifest banner and **Verify checksum** on a map pack.
- **Narration:** "A Resilience Node runs on a Raspberry Pi with no internet.
  Phones reconcile through it, and it serves map packs with a signed manifest.
  The app verifies the Ed25519 signature against a trusted root, then checks each
  file's SHA-256 before trusting it. Downloads resume over HTTP Range."

### 3:30-4:15 - Transport matrix + QR transfer

- **Show:** Network Status transport matrix with its honest labels (Cloud
  reachable, Node connected, Nearby/BLE **needs real device**, LoRa **needs real
  hardware**, QR idle). Then demo **Transfer by QR** between two devices if you
  have them, or show the animated QR on screen and explain it.
- **Narration:** "Network Status tells the truth about every transport. QR
  transfer uses a fountain code so a camera that drops frames still recovers the
  data, and the payload is SHA-256 and signature verified before anything is
  stored. BLE and LoRa are built and unit-tested, but they need real radios, so
  I am not going to pretend they are live on this screen."

### 4:15-5:00 - AI assist + honest close

- **Show:** the Home summary bar, the translate panel on an incoming message or
  a note (original text kept), and a non-blocking duplicate check before
  submitting a request. Point out the degraded chip when rules (not Bedrock)
  produced the text.
- **Narration:** "AI is optional and honest: Amazon Bedrock when it is
  reachable, a deterministic local fallback otherwise, always labelled. That is
  the system - local-first, signed, private, and honest about what works today
  versus what needs real hardware. Thanks for watching."

## Exact demo accounts / steps

- **Profile A / Profile B:** two separate browser profiles at the app URL; the
  app receives the API key from `/app-config.json`. No login - identity is a
  local keypair per profile.
- **Demo org:** `./scripts/seed-demo.sh` prints the org root public key; install
  it under Trusted organisations in whichever profile acts as the trusting user.
- **Verified providers:** the seed creates provider A (depth 1) and provider B
  (depth 2); both show verified once the root is trusted.

## Pitfalls to avoid on camera

- Do **not** show BLE/LoRa/Nearby as "connected" - they need real devices; show
  the honest `needs real device/hardware` labels instead.
- Do **not** demo the node/manifest flow from an HTTPS web page against a
  plain-HTTP LAN node - the browser blocks mixed content. Use native or an
  HTTPS node.
- Do **not** promise push notifications when the tab is closed - Web Push/VAPID
  is not built; the in-app banner only covers the open-app case.
- Estimated (dead-reckoning) position is **native-only**; on web it is honestly
  unavailable, so do not demo it in a browser.
- Give the map geolocation permission before recording, or "locate me" will
  stall on camera.
- Large package downloads on web do not persist a partial file across reloads
  (no filesystem) - demo resume on native if you want to show it.

## Honest limitations to say out loud (pick the relevant ones)

- "BLE, Nearby, and LoRa are built and unit-tested but need real radios; I am
  not faking them here."
- "Estimated position uses device sensors and is native-only; the web build says
  so honestly."
- "The web app has no filesystem, so a partial download does not survive a
  reload - it uses IndexedDB/OPFS."
- "Notifications only show while the app is open; background/closed-tab push is
  not built."
- "If I am on the live HTTPS site, I cannot reach a plain-HTTP node from the
  browser - that flow is on native."
