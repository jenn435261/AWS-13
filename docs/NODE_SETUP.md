# Resilience Node setup (end to end)

A **Resilience Node** turns any always-on box (a Raspberry Pi, an old laptop, a
mini-PC at a shelter) into a local hub so phones can reconcile with **no
internet**. This is the operator's guide: install, configure, add signed map
packs, pair a phone, run fully offline, attach a LoRa radio, back up/restore,
and troubleshoot.

The code is `node/cmd/resilience-node` (a self-contained Go module). Flags and
env vars below are taken verbatim from `node/cmd/resilience-node/main.go`;
`node/README.md` has the endpoint reference. Rule that holds everywhere: the
node serves only public, signed data, and it refuses to serve a package
manifest it cannot sign.

## 1. What a node does

- **Local event cache + sync server** so phones reconcile *through the node*
  over local Wi-Fi (phone A pushes, phone B pulls, B gets A's events). Every
  event is verified before storing; tampered events are rejected.
- **Offline web app** at `/` for phones with no native app (the iOS fallback).
- **Package / APK / map server** with HTTP Range so large PMTiles stream and
  resume, plus a **signed manifest** (`GET /node/v1/manifest`) the app verifies.
- **Pairing QR** at `/node/v1/pair.png`.
- **Optional cloud gateway** (bridges to the cloud when a link exists) and an
  **optional LoRa/Meshtastic serial gateway** (opt-in, needs real hardware).

## 2. Install

### Build from source (any Linux/macOS)

```sh
# Toolchain: Go 1.26 (GOTOOLCHAIN=auto downloads it). In this repo's sandbox:
#   export GOTOOLCHAIN=auto GOBIN=/projects/sandbox/.tc/gobin
cd node
go build ./...
go vet ./...
go test ./...
go build -o resilience-node ./cmd/resilience-node
```

### Docker

```sh
cd node
docker build -t resilience-node .
docker run --rm -p 8090:8090 \
  -e HTTP_ADDR=:8090 \
  -v "$PWD/data:/data" -e DATA_DIR=/data \
  resilience-node
```

The image is multi-stage and runs on distroless as a non-root user.

## 3. Configuration (flags override env)

| Env                    | Flag                     | Default   | Purpose |
| ---------------------- | ------------------------ | --------- | ------- |
| `HTTP_ADDR`            | `--http-addr`            | `:8090`   | HTTP listen address |
| `DATA_DIR`             | `--data-dir`             | (none)    | append-only event log dir; empty = in-memory only |
| `CLOUD_BASE_URL`       | `--cloud-base-url`       | (none)    | upstream cloud base URL; empty = offline only |
| `APK_DIR`              | `--apk-dir`              | (none)    | directory holding the Android APK |
| `MAP_DIR`              | `--map-dir`              | (none)    | directory holding `<region>.pmtiles` maps |
| `READINESS_DIR`        | `--readiness-dir`        | (none)    | directory holding readiness/first-aid bundles |
| `NODE_NAME`            | `--name`                 | `Resilience Node` | display name shown to phones that pair |
| `PUBLIC_URL`           | `--public-url`           | (none)    | address advertised in the pairing QR; default = the address the phone used |
| `PACKAGES_SIGNING_KEY` | `--packages-signing-key` | (none)    | path to a hex Ed25519 key (64 bytes) or seed (32 bytes); **empty disables the signed-manifest endpoint (returns 503)** |
|                        | `--sync-interval`        | `15s`     | cloud/mesh sync cadence |
| `LORA_SERIAL_PORT`     | `--lora-serial-port`     | (none)    | serial device of a Meshtastic radio to run the LoRa gateway; empty disables it. **Needs real hardware** |
| `LORA_BAUD`            | `--lora-baud`            | `115200`  | baud rate for the LoRa serial device |

### Ports, TLS and LAN

- The node speaks plain HTTP on `HTTP_ADDR` (default `:8090`). On a LAN this is
  fine: phones reach it at e.g. `http://192.168.4.1:8090`.
- **Mixed content:** an HTTPS web page (e.g. the cloud-hosted web app) **cannot**
  fetch a plain-HTTP LAN node - the browser blocks it. For web clients, either
  put the node behind HTTPS (a reverse proxy with a cert, or a self-signed cert
  the phones trust) or use the **native** app (no mixed-content rule). The
  native build is the reliable path for the node/manifest flow.
- **Chrome "local network" permission:** recent Chrome/Android builds prompt
  before a public HTTPS page may call a private-network address. The node sends
  `Access-Control-Allow-Private-Network: true` (see `cors` in `main.go`) so the
  preflight can succeed; the user must still accept the local-network prompt if
  the browser shows one.

## 4. Add map packs and build a signed manifest

1. Put `<region>.pmtiles` files in `MAP_DIR` (and any APK in `APK_DIR`,
   readiness bundles in `READINESS_DIR`). The node serves
   `GET /node/v1/map/{region}.pmtiles` with Range (206) so clients stream only
   the tiles they need. Only **raster** PMTiles render in the app today; vector
   archives fall back to online OSM with an honest banner.
2. Generate an Ed25519 signing key (keep the private half secret, never commit):

   ```sh
   # 32-byte seed as hex (one line). Store it as a file, chmod 600.
   head -c 32 /dev/urandom | xxd -p -c 32 > node-packages.key
   chmod 600 node-packages.key
   ```
3. Start the node with `--packages-signing-key node-packages.key`. On boot it
   logs the **public** key:

   ```
   package manifest signing enabled pubkey=<hex>
   ```
4. `GET /node/v1/manifest` now returns `{manifest, public_key, signature,
   algorithm:"ed25519"}` where the signature is a detached Ed25519 over the
   canonical compact JSON of the manifest, with a per-file SHA-256
   (`node/internal/packages/manifest.go`). Without a key the endpoint returns
   **503** - the node will never hand out an unsigned manifest that merely looks
   trustworthy.
5. In the app, build with `--dart-define=PACKAGES_TRUSTED_ROOT=<that public
   hex>`. Offline Downloads then shows a **verified** manifest banner and can
   check a downloaded file's SHA-256 against the signed entry before trusting
   it. A different key shows an honest **untrusted**; no key shows
   **unavailable**.

## 5. Pair a phone by QR

1. Open `http://<node-address>:8090/node/v1/pair.png` in a browser, or let the
   app scan it. The QR encodes the node's advertised address (`PUBLIC_URL`, or
   the address the requesting phone used).
2. In the app: **More -> Resilience nodes -> Add -> Scan QR** (camera) or type
   the address by hand. Set the node active; use **Check** to confirm
   reachability. You can save several nodes, rename, and delete them.
3. Once active, the app pushes to `/node/v1/push` and pulls from
   `/node/v1/pull`, and uses the node's PMTiles map if it advertises one.

## 6. Run with no internet

- Leave `CLOUD_BASE_URL` unset. The node is fully authoritative locally: it
  accepts, verifies, stores and serves events with zero upstream.
- Put the node on a device acting as a Wi-Fi access point (`hostapd` +
  `dnsmasq` on a Pi is the classic recipe). Phones join the SSID and point at
  the node's LAN address. No DNS or internet is required.
- When a link later appears and `CLOUD_BASE_URL` is set, the gateway loop
  bridges local events up and pulls remote ones; when it is unset the bridge is
  a no-op and the node keeps serving locally.

### systemd

```ini
# /etc/systemd/system/resilience-node.service
[Unit]
Description=Resilience Node
After=network-online.target

[Service]
Environment=HTTP_ADDR=:8090
Environment=DATA_DIR=/var/lib/resilience-node
Environment=MAP_DIR=/var/lib/resilience-node/maps
Environment=APK_DIR=/var/lib/resilience-node/apk
Environment=PACKAGES_SIGNING_KEY=/var/lib/resilience-node/node-packages.key
ExecStart=/usr/local/bin/resilience-node
Restart=on-failure
User=resilience
Group=resilience

[Install]
WantedBy=multi-user.target
```

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now resilience-node
```

The daemon handles `SIGINT`/`SIGTERM` with a graceful 10s drain, so
`systemctl stop` / `docker stop` shut it down cleanly.

## 7. Attach a LoRa radio (Meshtastic)

**Needs real hardware. Not exercised in this repo's CI/sandbox** (there is no
radio). The pure-Go parse/reassemble/verify/store/rebroadcast path is
unit-tested from a canned stream (`node/internal/lora`); only the serial adapter
(`serial.go`) touches a device.

1. **Hardware:** an ESP32/nRF52 LoRa board flashed with **Meshtastic firmware** - Heltec V3, LilyGO T-Beam, or RAK4631 are known-good boards.
2. **Region/frequency:** set the correct band for your country (US915, EU868,
   ...) in the Meshtastic app/CLI **on the device**, not in the node. Using the
   wrong band is illegal and will not interoperate.
3. **Channel key:** all radios on a channel share a PSK. Keep it off git and
   distribute it out of band. The app's end-to-end Ed25519 signing is
   independent of and layered above the Meshtastic channel crypto.
4. **Serial device path:** connect the radio over USB and find its device node
   (e.g. `/dev/ttyUSB0` on Linux, `/dev/tty.usbserial-*` on macOS, `COM3` on
   Windows). Typical Meshtastic USB serial runs at **115200** baud.
5. **Enable the gateway (opt-in):**

   ```sh
   resilience-node --lora-serial-port /dev/ttyUSB0 --lora-baud 115200 \
     --map-dir /var/lib/resilience-node/maps
   # or: LORA_SERIAL_PORT=/dev/ttyUSB0 LORA_BAUD=115200 resilience-node ...
   ```
   On boot it logs `lora gateway started port=/dev/ttyUSB0 baud=115200`. The
   gateway reads length-delimited LoRa fragments, reassembles compact signed
   events, verifies and stores each one (dropping duplicates by event id), and
   rebroadcasts fresh SOS/alerts back to the mesh. Oversized or media-bearing
   events are refused rather than corrupted.
6. **Topology:** a phone with no internet reaches an internet-connected node by
   hopping over the mesh - the phone's LoRa transport sends compact signed
   events to a nearby node running this gateway. On the phone side the Meshtastic
   link is BLE/serial and needs a real device; see `docs/HOW_IT_WORKS.md` for the
   transport matrix.

## 8. Backup and restore

- **What to back up:** the append-only event log under `DATA_DIR`
  (`DATA_DIR/events.log`), your map packs in `MAP_DIR`, and the signing key file
  referenced by `PACKAGES_SIGNING_KEY`. The event log is the source of truth;
  the node re-folds state from it on boot.
- **Backup (node stopped or at rest):**

  ```sh
  sudo systemctl stop resilience-node
  tar czf resilience-node-backup-$(date +%F).tgz \
    -C /var/lib resilience-node
  sudo systemctl start resilience-node
  ```
- **Restore:** stop the node, extract the tarball back into place
  (`tar xzf ... -C /var/lib`), ensure file ownership matches the service user,
  and start it. Because every event is content-addressed and signed, a restored
  log re-verifies on load; a corrupted or tampered record is rejected, not
  silently trusted.
- **Keep the signing key safe and unchanged:** if you rotate it, every app that
  trusted the old public key must be rebuilt with the new
  `PACKAGES_TRUSTED_ROOT`, or it will honestly show the manifest as untrusted.

## 9. Troubleshooting

| Symptom | Likely cause / fix |
| --- | --- |
| `GET /node/v1/manifest` returns **503** | No signing key configured. Set `--packages-signing-key` / `PACKAGES_SIGNING_KEY`. The node intentionally refuses to serve an unsigned manifest. |
| App shows the manifest as **untrusted** | The app's `PACKAGES_TRUSTED_ROOT` does not match the node's signing public key. Rebuild the app with the exact hex the node logs at boot. |
| Web app cannot reach the node (console: mixed content / blocked) | An HTTPS page cannot call a plain-HTTP LAN node. Put the node behind HTTPS or use the native app. |
| Chrome blocks the call to a private address | Accept the browser's local-network prompt. The node already sends `Access-Control-Allow-Private-Network: true`. |
| Phone cannot find the node | Confirm both are on the same Wi-Fi, the address/port are right (`curl http://<addr>:8090/healthz` -> `{"status":"ok"}`), and no firewall blocks the port. |
| Map does not switch to offline tiles | The node must advertise a `kind:"map"` item in its catalog and the archive must be **raster** PMTiles. Vector archives fall back to online OSM (honest banner), not a blank map. |
| LoRa gateway will not start (`open lora serial`) | Wrong device path, the port is busy (the Meshtastic app is attached), wrong baud, or missing serial permissions (`dialout` group on Linux). |
| Range download does not resume | Confirm the node serves `206 Partial Content` (`curl -r 0-99 ...`); it uses `http.ServeContent`, so this works unless a proxy strips Range. On web the browser has no persistent partial file (see §limits in `docs/FEED_AND_DOWNLOADS.md`). |
| Events reset after restart | `DATA_DIR` is unset, so the log is in-memory only. Set `DATA_DIR` to persist. |

## 10. Quick verification

```sh
curl localhost:8090/healthz                 # {"status":"ok"}
curl localhost:8090/                         # the offline web app (HTML)
curl localhost:8090/node/v1/state            # folded resources/alerts JSON
curl localhost:8090/node/v1/have             # per-author high-water digest
curl -s localhost:8090/node/v1/manifest | head  # signed manifest (or 503 if unsigned)
curl -r 0-99 localhost:8090/node/v1/map/<region>.pmtiles -o /dev/null -D -  # expect 206
```
