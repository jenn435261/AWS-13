import 'dart:typed_data';

import '../core/event_store.dart';
import '../gen/resilience/v1/event.pb.dart';
import '../gen/resilience/v1/sync.pb.dart';

/// Glue between the loss-tolerant [QrFountainEncoder]/[QrFountainDecoder] layer
/// and the signed-event model (spec §6.1 "Transfer by QR").
///
/// The bytes carried by the fountain are a protobuf [EventBatch]. The fountain
/// guarantees the bytes arrive intact (per-frame CRC) and complete (whole
/// payload SHA-256); this layer then re-runs the *real* trust check — every
/// event is pushed through [EventStore.apply], which verifies the Ed25519
/// signature and BLAKE2b content hash before storing. A forged or tampered
/// event is rejected by `apply` exactly as it would be over any other
/// transport. The QR path grants robust delivery, never trust.
class QrTransfer {
  QrTransfer._();

  /// Serializes [events] into the payload bytes the fountain will chunk.
  static Uint8List encodePayload(Iterable<SignedEvent> events) {
    final batch = EventBatch(events: events);
    return batch.writeToBuffer();
  }

  /// Parses fountain-reassembled [payload] bytes back into an [EventBatch].
  /// Returns null if the bytes are not a valid batch.
  static EventBatch? decodePayload(Uint8List payload) {
    try {
      return EventBatch.fromBuffer(payload);
    } catch (_) {
      return null;
    }
  }

  /// Ingests every event in [payload] through [store], which verifies each one
  /// (signature + content hash) before persisting. Returns a tally.
  static Future<QrIngestResult> ingest(
    EventStore store,
    Uint8List payload,
  ) async {
    final batch = decodePayload(payload);
    if (batch == null) {
      return const QrIngestResult(applied: 0, duplicate: 0, invalid: 0);
    }
    final results = await store.applyAll(batch.events);
    int applied = 0;
    int duplicate = 0;
    int invalid = 0;
    for (final r in results) {
      switch (r.status) {
        case ApplyStatus.applied:
          applied++;
        case ApplyStatus.duplicate:
          duplicate++;
        case ApplyStatus.invalid:
          invalid++;
      }
    }
    return QrIngestResult(
      applied: applied,
      duplicate: duplicate,
      invalid: invalid,
    );
  }
}

/// Outcome of ingesting a QR-transferred batch.
class QrIngestResult {
  const QrIngestResult({
    required this.applied,
    required this.duplicate,
    required this.invalid,
  });

  final int applied;
  final int duplicate;
  final int invalid;

  int get total => applied + duplicate + invalid;

  @override
  String toString() =>
      'QrIngestResult(applied: $applied, duplicate: $duplicate, '
      'invalid: $invalid)';
}
