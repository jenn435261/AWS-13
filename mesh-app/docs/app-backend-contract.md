# What the app expects from the backend

This is a proposal for the backend teammate. It describes the phone app
only. Nothing here is a server, and the app ships no cloud keys.

The phone signs every event itself. A route confirms an item, or the item
stays on the phone and is sent again. Receivers, including the Node, drop
a second copy by event id.

## Envelope

An envelope is one thing waiting to leave the phone (`lib/models/envelope.dart`).

| Field | Meaning |
|---|---|
| `id` | Unique for this item. A retry keeps the same id. |
| `kind` | What it is: a help request, SOS, cancel, message, resource, vote, delivery step, and so on. |
| `subject` | The request, resource, mission, or channel it is about. |
| `author` | The sender's Resilience ID. |
| `createdAt` | When the phone created it, UTC. |
| `fields` | Plain values only: strings, numbers, booleans, and lists of those. Never coordinates. |
| `location` | The only coordinates. Absent unless the kind below allows them. |

Coordinates leave the phone only in these cases:

- a help request or SOS carries the place the person chose to send;
- a resource report carries the place the person put on the map;
- while this phone is carrying a delivery, its live position.

Anything else is stripped before it is queued. A live position that is
still waiting when the delivery ends is dropped, not sent late. Live
positions are not put on the Node or the cloud until they can be
end-to-end encrypted. Direct, restricted, and mission messages wait for
the same reason. The Node and the cloud store what they relay, so those
items must not be handed to them yet.

## Signed event

On the wire an envelope is one `resilience.v1.SignedEvent`
(`lib/data/wire/event_codec.dart`). The same envelope always becomes the
same event, whichever route carries it.

- `event_id` = BLAKE2b-256 of the canonical header without `event_id`, followed by the body.
- `signature` = Ed25519 over the canonical header with `event_id`, followed by the body.
- The author field is the 32-byte Ed25519 public key.
- `lamport` orders one author's events. `prev` is that author's previous event id.

The canonical header writes fields in protobuf number order and leaves
defaults out. JSON uses protojson: camelCase names, bytes in base64,
64-bit numbers as strings.

An acknowledgement names ids, not a single yes:

- `applied`: stored, or already stored. Do not store a second copy. The phone will not send it again.
- `rejected`: refused for good (a bad signature or a revoked key). Sending it again would not help.

Anything else is treated as "not confirmed". The phone sends it again.

### Event types the app sends

These numbers are `resilience.v1.EventType`. Rows marked proposed are
types the app needs that `event.proto` does not number yet. The app
stores them in one place (`WireType`) so they can change together.

Numbers already in `event.proto` use that file's names. A proposed
number has no name there yet; the label below is only so this note can
point at it.

| App kind | Number | Proto name |
|---|---|---|
| resource created | 10 | `EVENT_TYPE_RESOURCE_CREATED` |
| resource removed | 11 | `EVENT_TYPE_RESOURCE_UPDATED` (body says withdrawn) |
| vote confirm | 13 | `EVENT_TYPE_RESOURCE_CONFIRMED` |
| vote dispute | 14 | `EVENT_TYPE_RESOURCE_DISPUTED` |
| vote useful | 15 | `EVENT_TYPE_RESOURCE_USEFUL` |
| vote withdrawn | 18 | proposed, no proto name yet |
| help request, SOS | 20 | `EVENT_TYPE_HELP_REQUESTED` (an SOS uses priority critical) |
| offer | 21 | `EVENT_TYPE_HELP_OFFERED` |
| help cancelled | 24 | `EVENT_TYPE_HELP_REQUEST_CLOSED` (body: field 1 = request id) |
| help accepted | 25 | proposed, no proto name yet |
| help released | 26 | proposed, no proto name yet |
| offer withdrawn | 27 | proposed, no proto name yet |
| public or community message | 30 | `EVENT_TYPE_MESSAGE_SENT` |
| mission accepted | 41 | `EVENT_TYPE_MISSION_ACCEPTED` |
| package picked up | 43 | `EVENT_TYPE_PACKAGE_PICKED_UP` |
| package transferred | 44 | `EVENT_TYPE_PACKAGE_TRANSFERRED` |
| delivery completed | 45 | `EVENT_TYPE_DELIVERY_COMPLETED` |
| mission released | 48 | proposed, no proto name yet |
| stop sharing location | 61 | `EVENT_TYPE_LOCATION_STOP` |

## Resilience Node

The app calls the Node on the local network. The base address comes from
`NODE_URL` (default `http://192.168.4.1:8090`). Paths below are on that
origin. The client is `lib/data/node_client.dart`.

| Call | What the app sends | What the app reads |
|---|---|---|
| `GET /healthz` | nothing | `200` and `{"status":"ok"}` means the Node is up. Anything else means it is down. |
| `POST /node/v1/push` | `{"events":[ SignedEvent, ... ]}` | `{"ack":{"applied":[base64 ids],"rejected":[base64 ids]}}`. Ids the app already sent are applied again and not stored twice. |
| `POST /node/v1/pull` | `{"from":[{"authorPubkey":base64,"fromLamport":"<n>"}],"limit":n}` | `{"batch":{"events":[ SignedEvent, ... ]}}`. Authors not named come back in full. The app keeps only events whose id and signature check out. |
| `GET /node/v1/have` | nothing | `{"authors":[{"author":"<hex public key>","high_water":n,"head_event_id":"..."}]}` |
| `GET /node/v1/state` | nothing | `{"resources":[...],"alerts":[...],"requests":[...],"count":n}`. A coarse public view: no exact positions, no authors, no message text. The app reads `title` on a resource and `freeform` on a request. |

Push and pull bodies are protojson. `/have` and `/state` are read with
the field names in the table, which are the names the app parses today.

## AWS IoT Core, a suggestion

This layout is a suggestion. The backend teammate decides the real
topics, certificates, and rules. The app does not connect to AWS yet.
`CloudTopics` in `lib/data/transport/cloud_transport.dart` is the only
place these names exist.

Prefix: `resilience/v1`.

| Topic | Direction | Payload |
|---|---|---|
| `resilience/v1/devices/{deviceId}/events` | phone to cloud | one `SignedEvent`, protobuf bytes, QoS 1 |
| `resilience/v1/devices/{deviceId}/inbox` | cloud to that phone | replies, receipts, and events meant for it, QoS 1 |
| `resilience/v1/areas/{areaId}/events` | cloud to everyone in an area | alerts and public events, QoS 1 |

`{deviceId}` is the phone's Resilience ID. The broker's PUBACK is the
acknowledgement that this phone's copy may leave the outbox. A publish
that fails before PUBACK is not acknowledged, and the phone sends it
again. The same event id must be safe to receive twice.
