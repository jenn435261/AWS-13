import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart' as pb;

import '../gen/resilience/v1/event.pb.dart';
import 'canonical.dart';
import 'hashing.dart';
import 'lamport_clock.dart';
import 'signing.dart';

/// The schema version stamped on events this build produces.
const int kEventSchemaVersion = 1;

/// Builds and verifies [SignedEvent]s.
///
/// An [EventFactory] turns an author's intent (an event [EventType] + a body)
/// into a fully-formed, content-addressed, signed event following the exact
/// recipe from the project spec:
///
/// 1. Allocate a Lamport timestamp: `lamport = clock.tick()`
///    (== `max(all seen) + 1`).
/// 2. Fill the header: type, author pubkey, lamport, `prev_event_id` (the
///    author's previous event head, forming a per-author hash chain),
///    `depends_on` (causal references), advisory `created_at_ms`,
///    `schema_version`, optional `h3_cell`.
/// 3. Serialize the body canonically.
/// 4. Compute `event_id = BLAKE2b-256(canonicalHeader(no id) || body)` and set
///    it on the header.
/// 5. Sign `canonicalHeader(with id) || body` with Ed25519 and attach the
///    64-byte signature.
///
/// [verifyEvent] reverses this: it recomputes the id, checks it matches the
/// stored id, checks the type is set, and verifies the signature.
class EventFactory {
  final Signer _signer;

  EventFactory({Signer? signer}) : _signer = signer ?? Signer();

  /// Builds a signed event from raw [bodyBytes].
  ///
  /// * [keyPair] — the author's Ed25519 keypair. Its public key is written into
  ///   the header and it is used to sign.
  /// * [clock] — the author's Lamport clock. [LamportClock.tick] is invoked
  ///   exactly once to allocate this event's timestamp.
  /// * [type] — the event type discriminator; must not be
  ///   `EVENT_TYPE_UNSPECIFIED`.
  /// * [bodyBytes] — the already-serialized body for [type].
  /// * [prevEventId] — the author's previous event id (the per-author chain
  ///   head). Omit/empty for the author's first event.
  /// * [dependsOn] — ids of events this one causally references.
  /// * [createdAtMs] — advisory wall-clock millis. Defaults to "now". Never
  ///   authoritative for ordering.
  /// * [h3Cell] — optional coarse geospatial bucket.
  Future<SignedEvent> buildFromBytes({
    required KeyPairData keyPair,
    required LamportClock clock,
    required EventType type,
    required List<int> bodyBytes,
    List<int>? prevEventId,
    List<List<int>>? dependsOn,
    Int64? createdAtMs,
    Int64? h3Cell,
    int schemaVersion = kEventSchemaVersion,
  }) async {
    if (type == EventType.EVENT_TYPE_UNSPECIFIED) {
      throw ArgumentError.value(
          type, 'type', 'Event type must be specified');
    }

    final Int64 lamport = clock.tick();
    final Int64 createdAt = createdAtMs ??
        Int64(DateTime.now().toUtc().millisecondsSinceEpoch);

    final Uint8List body = Uint8List.fromList(bodyBytes);

    final EventHeader header = EventHeader(
      type: type,
      authorPubkey: keyPair.publicKey,
      lamport: lamport,
      createdAtMs: createdAt,
      schemaVersion: schemaVersion,
    );
    if (prevEventId != null && prevEventId.isNotEmpty) {
      header.prevEventId = Uint8List.fromList(prevEventId);
    }
    if (dependsOn != null && dependsOn.isNotEmpty) {
      header.dependsOn
          .addAll(dependsOn.map((e) => Uint8List.fromList(e)));
    }
    if (h3Cell != null && h3Cell != Int64.ZERO) {
      header.h3Cell = h3Cell;
    }

    // Content-address: event_id = BLAKE2b-256(canonical header without id || body).
    final Uint8List id = blake2b256(hashPreimage(header, body));
    header.eventId = id;

    // Sign canonical header WITH id, concatenated with the body.
    final Uint8List signature =
        await _signer.sign(keyPair, signaturePreimage(header, body));

    return SignedEvent(
      header: header,
      body: body,
      signature: signature,
    );
  }

  /// Convenience wrapper that serializes a [pb.GeneratedMessage] body
  /// canonically before building.
  Future<SignedEvent> buildFromMessage({
    required KeyPairData keyPair,
    required LamportClock clock,
    required EventType type,
    required pb.GeneratedMessage body,
    List<int>? prevEventId,
    List<List<int>>? dependsOn,
    Int64? createdAtMs,
    Int64? h3Cell,
    int schemaVersion = kEventSchemaVersion,
  }) {
    return buildFromBytes(
      keyPair: keyPair,
      clock: clock,
      type: type,
      bodyBytes: canonicalBytes(body),
      prevEventId: prevEventId,
      dependsOn: dependsOn,
      createdAtMs: createdAtMs,
      h3Cell: h3Cell,
      schemaVersion: schemaVersion,
    );
  }

  /// Fully verifies a [event]:
  ///
  /// 1. The header type must be set (not `EVENT_TYPE_UNSPECIFIED`).
  /// 2. The author pubkey must be a 32-byte Ed25519 key.
  /// 3. The stored `event_id` must equal the recomputed content hash
  ///    (`BLAKE2b-256(canonicalHeader(no id) || body)`) — detects any body or
  ///    header tampering.
  /// 4. The signature must be a valid Ed25519 signature by `author_pubkey` over
  ///    `canonicalHeader(with id) || body`.
  ///
  /// Returns `false` (never throws) if any check fails.
  Future<bool> verifyEvent(SignedEvent event) async {
    try {
      if (!event.hasHeader()) return false;
      final EventHeader header = event.header;

      if (!header.hasType() ||
          header.type == EventType.EVENT_TYPE_UNSPECIFIED) {
        return false;
      }
      if (header.authorPubkey.length != 32) return false;
      if (event.signature.length != 64) return false;
      if (header.eventId.length != blake2bDigestLengthBytes) return false;

      final List<int> body = event.body;

      // 3. Recompute the content hash and compare to the stored id.
      final Uint8List recomputed = blake2b256(hashPreimage(header, body));
      if (!_bytesEqual(recomputed, header.eventId)) {
        return false;
      }

      // 4. Verify signature over header(with id) || body.
      final Uint8List preimage = signaturePreimage(header, body);
      return await _signer.verify(
        header.authorPubkey,
        preimage,
        event.signature,
      );
    } catch (_) {
      return false;
    }
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
