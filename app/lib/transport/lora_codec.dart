import 'dart:typed_data';

import '../gen/resilience/v1/event.pb.dart';

/// Compact signed-event envelope + fragmentation for the LoRa / Meshtastic path
/// (spec §6.3).
///
/// LoRa links are extremely narrow: a single Meshtastic packet carries roughly
/// 200-230 usable payload bytes and the air-time budget is tiny. So this path
/// is deliberately restricted:
///
///   * **Only compact event kinds** may be sent — SOS / help requests, supply
///     status, alert ACKs, emergency alerts, and location pings. Anything with
///     a photo, audio, or free-form blob is refused ([isLoraEligible]). Never
///     media over LoRa.
///   * Events are carried as their **full `SignedEvent` protobuf bytes** so the
///     receiver can still verify the Ed25519 signature + BLAKE2b content hash.
///     Protobuf is already compact; we do not add a lossy re-encoding that
///     would break the signature. The "binary-compressed envelope" is the
///     protobuf plus a tiny fragment header — compression here means "carry the
///     minimum bytes that still verify", not a generic compressor.
///   * A payload larger than one fragment is **fragmented** across several LoRa
///     packets, each <= [maxFragmentBytes]. The receiver reassembles by message
///     id and **dedupes whole messages by event id** so a rebroadcast storm on
///     the mesh never double-applies an event.
///
/// Wire layout of one fragment (big-endian):
/// ```
/// magic 'L'            (1 byte, 0x4c)
/// version              (1 byte, = 1)
/// msgId                (2 bytes)  groups fragments of one event together
/// fragIndex            (1 byte)   0-based
/// fragCount            (1 byte)   total fragments for this msgId (>=1)
/// bodyLen              (1 byte)   length of the fragment body that follows
/// body                 (bodyLen bytes) slice of the SignedEvent bytes
/// ```
/// The 7-byte header keeps the body budget at [maxFragmentBytes] - 7.
class LoraCodec {
  LoraCodec._();

  static const int magic = 0x4c; // 'L'
  static const int version = 1;
  static const int headerLen = 7;

  /// Max bytes in a single LoRa fragment (header + body). Meshtastic's usable
  /// payload is ~230 bytes; we stay just under to leave room for its own
  /// framing.
  static const int maxFragmentBytes = 222;

  /// Max body bytes per fragment.
  static const int maxBodyBytes = maxFragmentBytes - headerLen;

  /// Max fragments per message (fragCount is a single byte).
  static const int maxFragments = 255;

  /// Largest SignedEvent payload the LoRa path will carry.
  static const int maxPayloadBytes = maxBodyBytes * maxFragments;

  /// Event kinds small and urgent enough to justify LoRa air-time. Everything
  /// else (anything that could carry media/large blobs) is refused.
  static bool isLoraEligible(EventType type) {
    switch (type) {
      case EventType.EVENT_TYPE_HELP_REQUESTED:
      case EventType.EVENT_TYPE_HELP_OFFERED:
      case EventType.EVENT_TYPE_HELP_REQUEST_CLOSED:
      case EventType.EVENT_TYPE_EMERGENCY_ALERT:
      case EventType.EVENT_TYPE_RESOURCE_CREATED:
      case EventType.EVENT_TYPE_RESOURCE_UPDATED:
      case EventType.EVENT_TYPE_RESOURCE_OBSERVED:
      case EventType.EVENT_TYPE_LOCATION_SHARE:
      case EventType.EVENT_TYPE_LOCATION_STOP:
        return true;
      default:
        return false;
    }
  }

  /// Fragments a [SignedEvent] into LoRa frames.
  ///
  /// Throws [LoraTooLargeException] if the event does not fit the LoRa budget,
  /// and [LoraIneligibleException] if its kind is not LoRa-eligible. The caller
  /// chooses [msgId] (e.g. derived from the event id) so fragments of the same
  /// event can be grouped by the receiver.
  static List<Uint8List> fragmentEvent(SignedEvent event, {required int msgId}) {
    if (!isLoraEligible(event.header.type)) {
      throw LoraIneligibleException(event.header.type);
    }
    final payload = event.writeToBuffer();
    return fragmentBytes(payload, msgId: msgId);
  }

  /// Fragments raw [payload] bytes. Exposed for testing and for callers that
  /// already hold serialized bytes.
  static List<Uint8List> fragmentBytes(Uint8List payload, {required int msgId}) {
    if (payload.isEmpty) {
      throw ArgumentError('payload must not be empty');
    }
    if (payload.length > maxPayloadBytes) {
      throw LoraTooLargeException(payload.length, maxPayloadBytes);
    }
    final count = (payload.length + maxBodyBytes - 1) ~/ maxBodyBytes;
    final frames = <Uint8List>[];
    for (int i = 0; i < count; i++) {
      final start = i * maxBodyBytes;
      final end =
          (start + maxBodyBytes <= payload.length) ? start + maxBodyBytes : payload.length;
      final bodyLen = end - start;
      final frame = Uint8List(headerLen + bodyLen);
      frame[0] = magic;
      frame[1] = version;
      frame[2] = (msgId >> 8) & 0xff;
      frame[3] = msgId & 0xff;
      frame[4] = i;
      frame[5] = count;
      frame[6] = bodyLen;
      frame.setRange(headerLen, headerLen + bodyLen, payload, start);
      frames.add(frame);
    }
    return frames;
  }

  /// Parses one fragment, returning null if malformed.
  static LoraFragment? parseFragment(Uint8List frame) {
    if (frame.length < headerLen) return null;
    if (frame[0] != magic || frame[1] != version) return null;
    final msgId = (frame[2] << 8) | frame[3];
    final index = frame[4];
    final count = frame[5];
    final bodyLen = frame[6];
    if (count == 0 || index >= count) return null;
    if (frame.length != headerLen + bodyLen) return null;
    final body = Uint8List.fromList(frame.sublist(headerLen, headerLen + bodyLen));
    return LoraFragment(
      msgId: msgId,
      index: index,
      count: count,
      body: body,
    );
  }
}

/// A parsed LoRa fragment.
class LoraFragment {
  const LoraFragment({
    required this.msgId,
    required this.index,
    required this.count,
    required this.body,
  });

  final int msgId;
  final int index;
  final int count;
  final Uint8List body;
}

/// Raised when an event is too large for the LoRa path.
class LoraTooLargeException implements Exception {
  LoraTooLargeException(this.actual, this.max);
  final int actual;
  final int max;
  @override
  String toString() =>
      'LoraTooLargeException: payload $actual bytes exceeds LoRa cap $max';
}

/// Raised when an event kind is not permitted on LoRa (e.g. carries media).
class LoraIneligibleException implements Exception {
  LoraIneligibleException(this.type);
  final EventType type;
  @override
  String toString() => 'LoraIneligibleException: $type is not LoRa-eligible';
}

/// Reassembles fragments into complete payloads, out-of-order and
/// duplicate-tolerant, with whole-message dedupe by event id.
///
/// The reassembler is transport-agnostic: feed it every fragment you hear on
/// the mesh (including rebroadcasts) and it emits each complete [SignedEvent]
/// payload exactly once. Dedupe is by the reassembled bytes' identity — the
/// caller maps those bytes to a `SignedEvent` and verifies it before storing.
class LoraReassembler {
  LoraReassembler({this.maxPending = 64});

  /// How many in-flight messages to track before evicting the oldest.
  final int maxPending;

  // msgId -> partial assembly.
  final Map<int, _Pending> _pending = <int, _Pending>{};
  // Order of msgId arrival, for simple LRU eviction.
  final List<int> _order = <int>[];
  // Completed payloads already surfaced, keyed by a content fingerprint so a
  // rebroadcast (possibly under a different msgId) is not surfaced twice.
  final Set<String> _delivered = <String>{};

  /// Feeds one raw fragment. Returns the fully-reassembled payload bytes if
  /// this fragment completed a message that has not been delivered before,
  /// otherwise null (incomplete, duplicate, malformed).
  Uint8List? addFragment(Uint8List frame) {
    final frag = LoraCodec.parseFragment(frame);
    if (frag == null) return null;
    return addParsed(frag);
  }

  /// Feeds an already-parsed fragment.
  Uint8List? addParsed(LoraFragment frag) {
    var pending = _pending[frag.msgId];
    if (pending == null) {
      pending = _Pending(frag.count);
      _pending[frag.msgId] = pending;
      _order.add(frag.msgId);
      _evictIfNeeded();
    }
    if (frag.count != pending.count) {
      // Conflicting fragment count for this msgId: ignore the stray fragment.
      return null;
    }
    pending.parts[frag.index] = frag.body; // idempotent for duplicates
    if (!pending.isComplete) return null;

    final payload = pending.assemble();
    _pending.remove(frag.msgId);
    _order.remove(frag.msgId);

    final fp = _fingerprint(payload);
    if (!_delivered.add(fp)) {
      // Already delivered this exact payload via another path/rebroadcast.
      return null;
    }
    return payload;
  }

  void _evictIfNeeded() {
    while (_order.length > maxPending) {
      final oldest = _order.removeAt(0);
      _pending.remove(oldest);
    }
  }

  static String _fingerprint(Uint8List bytes) {
    // FNV-1a 64-bit over the bytes; cheap and collision-resistant enough for
    // dedupe (the real identity check is the event's own hash/signature).
    int hash = 0xcbf29ce484222325;
    const int prime = 0x100000001b3;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * prime) & 0xffffffffffffffff;
    }
    return hash.toRadixString(16);
  }
}

class _Pending {
  _Pending(this.count) : parts = List<Uint8List?>.filled(count, null);
  final int count;
  final List<Uint8List?> parts;

  bool get isComplete => parts.every((p) => p != null);

  Uint8List assemble() {
    final builder = BytesBuilder();
    for (final p in parts) {
      builder.add(p!);
    }
    return builder.toBytes();
  }
}
