# Resilience Node

The **Resilience Node** is a small Linux daemon that turns any always-on box
(a Raspberry Pi, an old laptop, a mini-PC at a shelter) into a local hub for the
Resilience Network during an outage. It runs with **no internet**:

- a **local event cache + sync server** so phones reconcile *through the node*
  over local Wi-Fi (phone A pushes, phone B pulls, B gets A's events);
- an **offline web app** served at `/` — the iOS / no-native-app fallback;
- a **package / APK / map server** with HTTP range support for large PMTiles;
- an **optional cloud/mesh gateway** that bridges to the cloud when a link is
  available and leaves a clean seam for a future LoRa mesh (Wave 7).

It is a **self-contained Go module** (`github.com/resilience-network/aws13/node`)
with its own `go.mod`. It does **not** depend on the cloud module: the event
verify/canonical/hash logic and the protobuf types are vendored locally so an
event that verifies in the cloud verifies here, byte-for-byte.

## Build, test, run

```sh
source /projects/sandbox/.toolchain/env.sh   # Go 1.26 toolchain

cd node
go build ./...     # compiles the daemon and all packages
go vet ./...       # static checks
go test ./...      # unit + httptest integration tests

go run ./cmd/resilience-node      # boots on :8090 with no cloud
```

Then, from another terminal:

```sh
curl localhost:8090/healthz           # {"status":"ok"}
curl localhost:8090/                  # the offline web app (HTML)
curl localhost:8090/node/v1/state     # folded resources/alerts JSON
curl localhost:8090/node/v1/have      # per-author high-water digest
```

## Configuration (flags override env)

| Env               | Flag               | Default | Purpose                                              |
| ----------------- | ------------------ | ------- | ---------------------------------------------------- |
| `HTTP_ADDR`       | `--http-addr`      | `:8090` | HTTP listen address                                  |
| `DATA_DIR`        | `--data-dir`       | (none)  | append-only event log dir; empty = in-memory only    |
| `CLOUD_BASE_URL`  | `--cloud-base-url` | (none)  | upstream cloud base URL; empty = offline only        |
| `APK_DIR`         | `--apk-dir`        | (none)  | directory holding the Android APK                    |
| `MAP_DIR`         | `--map-dir`        | (none)  | directory holding `<region>.pmtiles` maps            |
| `READINESS_DIR`   | `--readiness-dir`  | (none)  | directory holding readiness/first-aid bundles        |
|                   | `--sync-interval`  | `15s`   | cloud/mesh sync cadence                              |

## Endpoints

### Sync (phones reconcile over local Wi-Fi)

| Method | Path               | Body / result                                              |
| ------ | ------------------ | ---------------------------------------------------------- |
| POST   | `/node/v1/push`    | `PushEventsRequest` (proto or JSON) → `PushEventsResponse` with applied/rejected ids. Every event is **verified before storing**; tampered events are rejected and never stored. |
| POST   | `/node/v1/pull`    | `PullEventsRequest` with per-author watermarks → `PullEventsResponse` carrying only the events the caller is missing. |
| GET    | `/node/v1/have`    | JSON per-author high-water digest (author, high_water, head_event_id). |
| GET    | `/node/v1/state`   | JSON of current resources / alerts / requests folded from stored events. |
| GET    | `/healthz`         | Liveness.                                                  |

Content negotiation: push/pull speak protobuf by default and JSON when the
request `Content-Type`/`Accept` is `application/json`.

### Web app

| Method | Path | Result                                            |
| ------ | ---- | ------------------------------------------------- |
| GET    | `/`  | The dependency-free offline web app (vanilla HTML/JS, no CDN). It fetches `/node/v1/state` and renders alerts, resources, and emergency instructions. |

### Packages / maps (HTTP range supported)

| Method | Path                               | Result                                   |
| ------ | ---------------------------------- | ---------------------------------------- |
| GET    | `/node/v1/apk`                     | The Android APK from `APK_DIR`.          |
| GET    | `/node/v1/map/{region}.pmtiles`    | Offline map from `MAP_DIR`. Supports `Range` (206 Partial Content) so clients stream only the tiles they need. |
| GET    | `/node/v1/readiness/{id}`          | Readiness bundle from `READINESS_DIR`.   |

Missing files return `404`. Path traversal is rejected.

## Deployment

### Wi-Fi access point

Run the node on a device acting as a Wi-Fi AP (e.g. `hostapd` + `dnsmasq` on a
Raspberry Pi). Phones join the AP's SSID and point their browser or native app
at the node's LAN address (for example `http://192.168.4.1:8090`). No upstream
internet is required; the node is authoritative for what it accepts and stores.

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

### Optional: AWS IoT Greengrass

The node is a single static binary, which makes it a natural **Greengrass
component**: package `resilience-node` as a component artifact, set the config
vars (`HTTP_ADDR`, `DATA_DIR`, `CLOUD_BASE_URL`, `MAP_DIR`, …) as component
configuration, and let Greengrass manage lifecycle and OTA updates on edge
gateways. When `CLOUD_BASE_URL` is set, the node's gateway loop bridges local
events to the cloud and pulls remote ones; when it is unset, the node runs fully
offline.

## Gateway & mesh

The gateway sits behind small interfaces so the node is testable and
future-proof:

- **`CloudClient`** — the upstream API (`Push` / `Pull`). The real
  implementation (`HTTPCloud`) talks protobuf to the cloud's `/v1/events` and
  `/v1/events/pull`. Tests use a fake. When `CLOUD_BASE_URL` is empty the cloud
  bridge is a no-op and the node keeps serving locally.
- **`MeshBridge`** — the transport seam for a radio mesh. The default is
  `NopMesh`. **Wave-7 LoRa** plugs in here: implement `MeshBridge` over a LoRa
  radio and wire it into `gateway.Options.Mesh`; the gateway loop already calls
  `Start` (inbound) and `Broadcast` (outbound), so nothing else changes.
