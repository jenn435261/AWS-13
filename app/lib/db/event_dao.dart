import 'package:drift/drift.dart';

import '../gen/resilience/v1/event.pb.dart';
import 'database.dart';

part 'event_dao.g.dart';

/// Opaque, order-insensitive key for an author's public key (bytes) so it can
/// be used in Dart [Map]s. Author pubkeys are raw bytes; wrap them for keys.
class AuthorKey {
  final Uint8List bytes;
  AuthorKey(List<int> b) : bytes = Uint8List.fromList(b);

  @override
  bool operator ==(Object other) {
    if (other is! AuthorKey) return false;
    if (bytes.length != other.bytes.length) return false;
    for (int i = 0; i < bytes.length; i++) {
      if (bytes[i] != other.bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    // FNV-1a over the bytes.
    int h = 0x811c9dc5;
    for (final int b in bytes) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }
}

/// Data-access object for the event log. This is the local event store: the
/// durable, content-addressed set of signed events over which application state
/// is folded.
@DriftAccessor(tables: [Events])
class EventDao extends DatabaseAccessor<AppDatabase> with _$EventDaoMixin {
  EventDao(super.db);

  /// Inserts [event], de-duplicating by `event_id`.
  ///
  /// Returns `true` if the event was newly stored, `false` if an event with the
  /// same content hash was already present (in which case nothing is written).
  ///
  /// [valid] records whether the caller verified the event; defaults to `true`.
  Future<bool> insertEvent(SignedEvent event, {bool valid = true}) async {
    final EventHeader h = event.header;
    final companion = EventsCompanion.insert(
      eventId: Uint8List.fromList(h.eventId),
      type: h.type.value,
      authorPubkey: Uint8List.fromList(h.authorPubkey),
      lamport: h.lamport.toInt(),
      prevEventId: Value(h.hasPrevEventId() && h.prevEventId.isNotEmpty
          ? Uint8List.fromList(h.prevEventId)
          : null),
      createdAtMs: Value(h.createdAtMs.toInt()),
      h3Cell: Value(h.h3Cell.toInt()),
      raw: Uint8List.fromList(event.writeToBuffer()),
      valid: Value(valid),
    );

    // Dedup by content-hash primary key. We check-then-insert inside a
    // transaction so concurrent applies cannot both believe they inserted.
    // (insertOrIgnore's return value is not a reliable "did we insert?" signal
    // across sqlite builds, so we rely on an explicit existence check.)
    return transaction<bool>(() async {
      final bool already = await _containsInternal(h.eventId);
      if (already) return false;
      await into(events).insert(companion, mode: InsertMode.insertOrIgnore);
      return true;
    });
  }

  Future<bool> _containsInternal(List<int> eventId) async {
    final query = selectOnly(events)
      ..addColumns([events.eventId])
      ..where(events.eventId.equals(Uint8List.fromList(eventId)))
      ..limit(1);
    final rows = await query.get();
    return rows.isNotEmpty;
  }

  /// Returns the [SignedEvent] with the given [eventId], or `null` if absent.
  Future<SignedEvent?> getEvent(List<int> eventId) async {
    final row = await (select(events)
          ..where((t) => t.eventId.equals(Uint8List.fromList(eventId))))
        .getSingleOrNull();
    if (row == null) return null;
    return SignedEvent.fromBuffer(row.raw);
  }

  /// Returns every stored event, ordered by (lamport, event_id) for a stable,
  /// deterministic traversal.
  Future<List<SignedEvent>> allEvents() async {
    final rows = await (select(events)
          ..orderBy([
            (t) => OrderingTerm(expression: t.lamport),
            (t) => OrderingTerm(expression: t.eventId),
          ]))
        .get();
    return rows.map((r) => SignedEvent.fromBuffer(r.raw)).toList();
  }

  /// Returns events by [author] whose lamport is strictly greater than
  /// [fromLamport], ordered ascending by (lamport, event_id).
  ///
  /// This backs the sync "give me everything after my watermark" request
  /// (`WantList.AuthorFrom`).
  Future<List<SignedEvent>> eventsByAuthorFrom(
    List<int> author,
    int fromLamport,
  ) async {
    final rows = await (select(events)
          ..where((t) =>
              t.authorPubkey.equals(Uint8List.fromList(author)) &
              t.lamport.isBiggerThanValue(fromLamport))
          ..orderBy([
            (t) => OrderingTerm(expression: t.lamport),
            (t) => OrderingTerm(expression: t.eventId),
          ]))
        .get();
    return rows.map((r) => SignedEvent.fromBuffer(r.raw)).toList();
  }

  /// Returns a map of author pubkey -> highest lamport value held for that
  /// author (the per-author high-water mark used in sync digests).
  Future<Map<AuthorKey, int>> highWaterByAuthor() async {
    final maxLamport = events.lamport.max();
    final query = selectOnly(events)
      ..addColumns([events.authorPubkey, maxLamport])
      ..groupBy([events.authorPubkey]);
    final rows = await query.get();
    final Map<AuthorKey, int> out = <AuthorKey, int>{};
    for (final row in rows) {
      final author = row.read(events.authorPubkey);
      final hw = row.read(maxLamport);
      if (author == null) continue;
      out[AuthorKey(author)] = hw ?? 0;
    }
    return out;
  }

  /// Returns the author's current chain head: the event with the highest
  /// lamport for [author] (ties broken by the larger event_id for
  /// determinism), or `null` if the author has no events.
  Future<SignedEvent?> headByAuthor(List<int> author) async {
    final rows = await (select(events)
          ..where((t) => t.authorPubkey.equals(Uint8List.fromList(author)))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.lamport, mode: OrderingMode.desc),
            (t) => OrderingTerm(
                expression: t.eventId, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .get();
    if (rows.isEmpty) return null;
    return SignedEvent.fromBuffer(rows.first.raw);
  }

  /// Returns the set of all stored event ids.
  Future<List<Uint8List>> allEventIds() async {
    final query = selectOnly(events)..addColumns([events.eventId]);
    final rows = await query.get();
    return rows
        .map((r) => r.read(events.eventId))
        .whereType<Uint8List>()
        .toList();
  }

  /// Whether an event with [eventId] is already stored.
  Future<bool> contains(List<int> eventId) async {
    final query = selectOnly(events)
      ..addColumns([events.eventId])
      ..where(events.eventId.equals(Uint8List.fromList(eventId)))
      ..limit(1);
    final rows = await query.get();
    return rows.isNotEmpty;
  }
}
