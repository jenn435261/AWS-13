import 'package:drift/drift.dart';

import 'connection/connection.dart' as conn;
import 'event_dao.dart';

part 'database.g.dart';

/// Local, append-only store of signed events (the folded-over log).
///
/// The `event_id` is the 32-byte BLAKE2b-256 content hash and serves as the
/// primary key, dedup key, and DAG node id. The full wire-format [SignedEvent]
/// is kept verbatim in [raw] so we can re-share it byte-for-byte over any
/// transport (sync is content-addressed; re-encoding would risk changing the
/// hash). Indexed columns ([type], [authorPubkey], [lamport], [h3Cell]) are
/// projected out of the header for efficient querying and sync reconciliation.
class Events extends Table {
  /// 32-byte BLAKE2b-256 content hash. Primary key / dedup key / DAG id.
  BlobColumn get eventId => blob()();

  /// [EventType] enum value (header.type).
  IntColumn get type => integer()();

  /// Author's 32-byte Ed25519 public key (header.author_pubkey).
  BlobColumn get authorPubkey => blob()();

  /// Lamport logical clock (header.lamport). Stored as an integer; values are
  /// conceptually uint64 but stay well within SQLite's signed 64-bit range for
  /// realistic event counts.
  IntColumn get lamport => integer()();

  /// Author's previous event id (per-author hash chain). Nullable/empty for the
  /// author's first event.
  BlobColumn get prevEventId => blob().nullable()();

  /// Advisory wall-clock millis (header.created_at_ms). Freshness UI only.
  IntColumn get createdAtMs => integer().withDefault(const Constant(0))();

  /// Optional coarse H3 geospatial bucket (header.h3_cell).
  IntColumn get h3Cell => integer().withDefault(const Constant(0))();

  /// The full `SignedEvent.writeToBuffer()` bytes, stored verbatim.
  BlobColumn get raw => blob()();

  /// Whether this event passed signature + hash verification at insert time.
  BoolColumn get valid => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {eventId};
}

/// Generic key/value store for engine state that is not itself an event:
/// identity keys, the persisted Lamport clock value, sync watermarks, etc.
class KeyValue extends Table {
  TextColumn get key => text()();
  BlobColumn get value => blob()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [Events, KeyValue], daos: [EventDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory database for tests (native FFI in-memory; WASM in-memory on web).
  AppDatabase.memory() : super(conn.openMemory());

  /// Opens the on-device database (native file; WASM/IndexedDB on web).
  factory AppDatabase.open() => AppDatabase(conn.openConnection());

  /// Deletes every event and every key/value row (contacts, settings). Used by
  /// the "Full wipe" data control.
  Future<void> wipeAll() => transaction(() async {
        await delete(events).go();
        await delete(keyValue).go();
      });

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
      );
}


