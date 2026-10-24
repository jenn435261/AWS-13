# Spec: providers, map, supplies, nodes, packages, media, languages

Status key: **Built** (in the app, tested) · **Partial** · **Spec only** (designed here, not built).
Everything here follows one rule: the UI never claims something works that is not wired.

## 1. Roles and what each can do

There is no central account system. A role is a fact any device derives from signed events and
the trust roots *that device* chose to trust.

| Role | How you get it | Can | Cannot |
|---|---|---|---|
| Community member | Default for every identity | Request help; publish supplies (shown as community); confirm / dispute / mark useful; add contacts; run nodes and packages locally | Post alerts; get a verified badge; certify anyone |
| Verified provider | Your key is a trusted root, or is certified by a chain from one (`ORG_CERTIFICATE`), and is not revoked | Everything above, plus: verified badge on supplies; **post emergency alerts**; **create missions**; read aggregate community needs (with a cloud org token) | Read others' messages; see anyone's exact location unless shared with them; remove or edit others' posts; revoke keys unless also a root |
| Organization root | A key the device owner explicitly trusted ("Trust my own key" when founding an org, or "Trust a contact") | Everything a provider can, plus **certify contacts** into the organization | Be trusted by anyone who did not add it themselves |
| Carrier / driver | Holds a mission capability (`CAPABILITY_GRANTED`) | Accept missions, scan package handoffs | Create missions |

Rules that make this safe (all enforced in `derived_state.dart`, tested in `supply_and_provider_test.dart`):

1. **Trust is local.** Roots are never learned from the event log, so nobody can mint their own badge. Trusting is a choice on the Trusted organizations screen and persists.
2. **Badges are re-derived, not claimed.** A post's `provenance` field is advisory. Each device walks the certificate chain itself.
3. **Only verified authors' alerts are shown.** A community member's `EMERGENCY_ALERT` is ignored.
4. **Only the owner changes a supply.** Edit (re-publish), restock, mark out, take down and relist from any other key are ignored.
5. Revoking a key (`KEY_REVOKED`) removes the badge from it and from anyone certified only through it.

Policy (resolved, FEAT-005): transitive issuance is allowed but bounded — a key is verified only if it is within a **certificate chain depth of 2** from a trusted root (root = depth 0, a directly certified key = depth 1, one more hop = depth 2 badge; depth 3+ confers no badge). Enforced in `OrgCertGraph.provenanceOf`; see `docs/DECISIONS.md`.

### 1.1 How a provider sends and receives

Everything is a signed event; transports only move bytes.

The app-side sync client now exists (FEAT-002), so the "once sync client exists" column is the path today:

| Direction | What | Path (Built) |
|---|---|---|
| Send | Verified supply, alert, mission, certificate | Written to the local log, visible immediately; **pushed** to a Resilience Node (`/node/v1/push`) and the cloud (`POST /v1/events`) by the sync client (nearby peers where available) |
| Receive | Requests, supplies, alerts from others | **Pulled** from the node (`/node/v1/pull`) and cloud (`/v1/events/pull`); every event is signature-checked before it is stored, so a relay cannot forge anything |
| Receive (aggregate) | Community needs by category | `GET /v1/org/needs` with an org token (Provider tools → Community needs). Shows only what has reached the cloud |
| Receive (mission) | Mission offers | Mission events in the log; carriers see them in Deliveries after sync |

Provider screen layout (Built): status card (verified or not, why) → if not verified, three steps to become one → if verified, actions (publish supply, post alert, create mission, certify contact if root) → what I published → community needs → "what providers cannot do".

**Mission assignment, acceptance and alert recall (Built, FEAT-005).** A verified provider assigns a mission to a named carrier (chosen from contacts) by emitting `MISSION_MATCHED`; the fold ignores a create/assign from a non-verified key (abuse rule). Carriers accept from the **Deliveries** tab by emitting `MISSION_ACCEPTED`. The Deliveries tab now renders the `MissionBucket` board (Assigned / Available / In transit / Awaiting handoff / Completed) from `logistics/mission.dart`. Alert recall is implemented as a new `EMERGENCY_ALERT` with the same `alert_id` and `expires_ms` in the past (author-only); the provider screen offers a **Recall** action on each live alert.

## 2. Map (Built)

- Real map via `flutter_map` with OpenStreetMap tiles; pan, zoom buttons, "My location".
- Plots, at true coordinates: supplies and shelters (green = verified org, blue = community), help requests (red). Anything without a location is **not** plotted; a chip says how many.
- "You" dot appears only after the user taps My location (browser/phone permission prompt). We never poll or track.
- Privacy: published coordinates are rounded to 3 decimals (~110 m). `has_exact` stays false unless a flow deliberately sets it (none do yet).
- Location is set per post with: use my location, pick on map, or none. Requests default to the last position the user read.
- Offline: online tiles need internet. **Built (FEAT-006):** when the active node serves `<region>.pmtiles` (`/node/v1/map/…`, Range supported), `app/lib/ui/map/pmtiles_tile_provider.dart` opens the archive over HTTP and renders its **raster** tiles; when no node map is available (or a tile is vector/unreachable) it falls back to the online OSM raster layer and shows an honest offline banner. (A full **vector** PMTiles renderer is still out of scope — `maplibre_gl` breaks the web build.) Respect the OSM tile usage policy: fine for a demo, not for sustained load; switch to the node PMTiles or a paid tile host before real use.
- Emergency alerts from verified authors show as a banner above the map until `expires_ms`. An author may **recall** an alert by re-issuing the same `alert_id` with `expires_ms` in the past (FEAT-005); the fold drops it immediately.
- Supplies past `available_until_ms` and closed requests are **auto-hidden** from the map (FEAT-005).

## 3. Supplies and availability (Built)

A supply is a `RESOURCE_CREATED` event plus an optional `INVENTORY_SNAPSHOT`.

| Field | Input | Stored as |
|---|---|---|
| Type | One category chip | `category` |
| What is it | Free text ("Bottled water") | `title` |
| Quantity | Whole number (optional) | `INVENTORY_SNAPSHOT.quantity` |
| Unit | Free text ("cases", "gallons", "beds") | `INVENTORY_SNAPSHOT.unit` |
| Rough level | Plenty / Some / Low | `amount` (use when you only know roughly) |
| Availability | Now / Today / **Until a date** (date picker) | `availability`, `available_until_ms` (end of that day) |
| Location | See §2 | `location` |
| Shelter | Toggle | `is_shelter` |
| Notes | Free text (pickup times, limits) | `notes` |

Lifecycle (My Supplies → ⋮ menu; log is append-only so nothing is erased):

| Action | Event | Result |
|---|---|---|
| Add | `RESOURCE_CREATED` (+ snapshot) | Listed, on the map if it has a location |
| Edit | Re-publish `RESOURCE_CREATED`, same `resource_id` | Latest wins; owner only; also relists |
| Update quantity | `INVENTORY_SNAPSHOT` | Authoritative count changes |
| Mark out of stock | Snapshot qty 0 + `RESOURCE_UPDATED amount=LOW` | Stays listed as "Out of stock" |
| Take down ("delete") | `RESOURCE_UPDATED withdrawn=true` | Hidden from the map, struck through in My Supplies; undo toast |
| Put back up | Re-publish `RESOURCE_CREATED` | Listed again. (A proto3 `withdrawn=false` is indistinguishable from "unset", so relisting cannot use an update) |
| Expires | `available_until_ms` passes (no event) | **Auto-hidden** from the map; shown as **Expired** in My Supplies (FEAT-005) |

My **requests** can be **closed/cancelled** (FEAT-005): My Requests shows a Close action that emits `HELP_REQUEST_CLOSED` (owner-only — a close from any other key is ignored). A closed request leaves the map and is struck through in My Requests; the record stays verifiable. Reservations by missions reduce *available* quantity but never the snapshot (existing rule). Supply expiry (`available_until_ms` in the past) now auto-hides a supply from the map via `WorldState.mapResources()` (FEAT-005).

## 4. Resilience nodes (Built) and the proof-of-concept node

- **Run one here:** `cd node && go run ./cmd/resilience-node --name "My Node" --apk-dir … --map-dir … --readiness-dir …` (flags/env in `node/README.md`). New: `--name`, `--public-url`.
- **Pairing QR:** `GET /node/v1/pair` returns `{"v":1,"name":…,"url":…}`; `GET /node/v1/pair.png` is a QR of the same JSON. The URL is the address the phone used to reach the node, unless `--public-url` pins it. Open `/node/v1/pair.png` on any screen and scan it from the app (More → Resilience nodes → Add node → Scan node QR), or type the address.
- **Saved nodes:** several allowed; rename, set active, check reachability (`/healthz`), delete with undo. Typing only an address pulls the node's own name from `/pair`. Stored locally only.
- **Catalog:** `GET /node/v1/packages` lists what the node really holds (kind, name, path, size, modified). The app never guesses file names.
- **CORS:** the node answers cross-origin reads so the https web app can reach `http://localhost:8090`. A browser still blocks an https page from reaching a plain-http LAN address (mixed content), and Chrome additionally asks permission before an https page may reach `localhost` or the LAN (Local Network Access; the node sends `Access-Control-Allow-Private-Network` so the prompt can succeed). Headless/denied means the node shows "Not reachable" (verified on the live site); on a real LAN use the native app, or give the node HTTPS (`--public-url https://…` behind a proxy).
- **Cloud API** is already running on Heroku (see `cloud/DEPLOY_HEROKU.md`); a node pointed at it with `--cloud-base-url` bridges events up when it has internet.
- **Signed manifest (Built, FEAT-007):** `GET /node/v1/manifest` returns the catalog with a per-file SHA-256 and a detached Ed25519 signature verifiable against a trusted root, so a rogue node cannot offer a malicious file undetected — the app verifies the signature against its configured trusted root, then checks a download's SHA-256 against the signed entry before trusting it (`node/internal/packages/manifest.go`, `app/lib/nodes/package_manifest.dart`). Enable node-side with `--packages-signing-key` / `PACKAGES_SIGNING_KEY`; without a key the endpoint returns 503 (the node refuses to serve an unsigned manifest). Files are served with HTTP Range so a large download can resume.
- Spec only: node discovery on the LAN (mDNS), node-side auth for pushes.

## 5. Offline downloads (Built)

My library = your own list of package versions: kind (app / map / readiness / other), name, version, link, notes. Add by hand or "Save to my library" from a node's catalog (version defaults to the file's modified date). Several versions of one name sit together, newest first. Per entry: download (opens the link), check link (HEAD), copy link, edit, delete with undo. Nothing is claimed to be downloaded on-device: the app stores *where* each version is; the browser/OS handles the file.

**Built (FEAT-007): checksum verification against a signed manifest.** When the node serves a signed manifest that verifies against the configured trusted root (`--dart-define=PACKAGES_TRUSTED_ROOT=<hex>`), Offline Downloads shows an honest manifest-trust banner and offers **Verify checksum**: it downloads the file and compares its SHA-256 to the signed entry, rejecting a mismatch loudly. The node serves files with HTTP **Range** so a large download can **resume** from a byte offset (proven in `node/internal/packages/manifest_test.go` `TestRangeResumeDownload`). Still spec only: true on-device background download with a progress bar + persistent partial-file resume (limited on web, which has no filesystem — the UI stays honest about this), and "keep the last N versions" pruning.

## 6. Messages with photos and audio (Built, FEAT-003)

Shipped end to end over the FEAT-002 sync client: a durable Drift-backed Signal store, prekey bundles published as
signed events, text + photo + voice-note messages, and content-addressed encrypted blobs. The design below is what was
built (relays/cloud see only ciphertext):

- **Message kinds:** text, image, audio, location (later). One `MessagePayload { kind, text, attachments[] }` inside the Signal ciphertext.
- **Attachments are encrypted blobs, not in the event.** Sender picks a random 256-bit key, encrypts the file (AES-GCM), uploads the ciphertext to a blob store, and sends `{sha256, size, mime, key, thumbnail}` inside the end-to-end encrypted message. Relays and the store see only ciphertext.
- **Limits for disrupted networks:** photos re-encoded to ≤1600 px JPEG/WebP (target ≤250 KB) with a ≤8 KB blurred thumbnail sent inline; audio Opus mono ≤60 s (~120 KB at 16 kbps). Over mesh / LoRa send only the thumbnail and a "full file when online" marker; full blobs move over IP (node or cloud).
- **Blob store:** `PUT/GET /v1/blobs/{sha256}` on the cloud and `/node/v1/blobs/{sha256}` on a node; content-addressed, size cap 2 MB, rate-limited, gated by the client API key, purged after 7 days. The recipient verifies the hash after decrypting.
- **UI:** attach button (camera / gallery), hold-to-record mic with cancel and 60 s cap, inline thumbnail with tap-to-load, audio bubble with play and duration, "queued" state while offline. Strip EXIF (including GPS) before encrypting.
- **Safety:** warn before sending a photo with detectable location context; never auto-download from unknown contacts on mobile data.

## 7. Languages (Built)

English, Spanish, French, Mandarin (Simplified). Strings are in `lib/l10n/` (`strings.dart` base, `strings_new.dart` additions, `strings_fr.dart`, `strings_zh.dart`). A test fails if French or Mandarin is missing a key English has. Selecting a language is in Settings; unselected means the system language. Notes: Mandarin text renders with the browser/OS CJK fallback font (the web build fetches it when needed); dates use the platform formatter. To add a language: add its map, add a `Locale`, add a name in `L10n.languageName`.

## 8. Decisions needed from the team

1. Transitive vs root-only certificate issuance (§1). **Resolved for this run:** transitive issuance is allowed up to a **certificate chain depth of 2** from a trusted root (depth 3+ confers no badge). Enforced in `OrgCertGraph.provenanceOf`; see `docs/DECISIONS.md`.
2. Which tile source for production (§2).
3. Whether providers may *assign* missions to specific carriers from the UI, or only publish them for carriers to accept (§1.1). **Resolved for this run:** both — a verified provider may assign a carrier via `MISSION_MATCHED` (verified-only) and carriers may also accept available missions via `MISSION_ACCEPTED` from Deliveries (FEAT-005).
4. Retention: how long do requests and supplies stay on the map after their last update? (Partially addressed: supplies past `available_until_ms` and closed requests now auto-hide from the map; a general time-based retention policy is still open.)
5. Where blobs live in production and who pays (§6).
