import 'package:drift/drift.dart';

import 'connection/connection.dart' as conn;
import 'event_dao.dart';
import 'signal_dao.dart';

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

/// Durable Signal Protocol key material (schema v2). These tables make the
/// Signal session state survive a restart so a running X3DH/Double-Ratchet
/// session is not lost when the app is closed. Every value is the vetted
/// libsignal record's own `serialize()` bytes — we never invent a key format.
///
/// Privacy: these rows hold private key material; they are NEVER logged and are
/// erased by the "Full wipe" data control (see [AppDatabase.wipeAll]).

/// Singleton row holding this device's long-term identity keypair and
/// registration id. [id] is always 0.
class SignalIdentity extends Table {
  IntColumn get id => integer()();

  /// `IdentityKeyPair.serialize()` bytes (public + private identity keys).
  BlobColumn get identityKeyPair => blob()();

  /// The device registration id.
  IntColumn get registrationId => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One-time prekeys, keyed by prekey id. Value is `PreKeyRecord.serialize()`.
class SignalPreKeys extends Table {
  IntColumn get preKeyId => integer()();
  BlobColumn get record => blob()();

  @override
  Set<Column<Object>> get primaryKey => {preKeyId};
}

/// Signed prekeys, keyed by signed-prekey id. Value is
/// `SignedPreKeyRecord.serialize()`.
class SignalSignedPreKeys extends Table {
  IntColumn get signedPreKeyId => integer()();
  BlobColumn get record => blob()();

  @override
  Set<Column<Object>> get primaryKey => {signedPreKeyId};
}

/// Double-Ratchet sessions, keyed by the remote address `name::deviceId`.
/// Value is `SessionRecord.serialize()`.
class SignalSessions extends Table {
  TextColumn get address => text()();
  BlobColumn get record => blob()();

  @override
  Set<Column<Object>> get primaryKey => {address};
}

/// Group Sender-Key records, keyed by `SenderKeyName.serialize()`. Value is
/// `SenderKeyRecord.serialize()`.
class SignalSenderKeys extends Table {
  TextColumn get senderKeyName => text()();
  BlobColumn get record => blob()();

  @override
  Set<Column<Object>> get primaryKey => {senderKeyName};
}

/// Trusted remote identity keys (TOFU), keyed by the remote address
/// `name::deviceId`. Value is `IdentityKey.serialize()`.
class SignalTrustedKeys extends Table {
  TextColumn get address => text()();
  BlobColumn get identityKey => blob()();

  @override
  Set<Column<Object>> get primaryKey => {address};
}

@DriftDatabase(tables: [
  Events,
  KeyValue,
  SignalIdentity,
  SignalPreKeys,
  SignalSignedPreKeys,
  SignalSessions,
  SignalSenderKeys,
  SignalTrustedKeys,
], daos: [
  EventDao,
  SignalDao,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory database for tests (native FFI in-memory; WASM in-memory on web).
  AppDatabase.memory() : super(conn.openMemory());

  /// Opens the on-device database (native file; WASM/IndexedDB on web).
  factory AppDatabase.open() => AppDatabase(conn.openConnection());

  /// Deletes every event and every key/value row (contacts, settings) plus all
  /// durable Signal key material. Used by the "Full wipe" data control.
  Future<void> wipeAll() => transaction(() async {
        await delete(events).go();
        await delete(keyValue).go();
        await delete(signalIdentity).go();
        await delete(signalPreKeys).go();
        await delete(signalSignedPreKeys).go();
        await delete(signalSessions).go();
        await delete(signalSenderKeys).go();
        await delete(signalTrustedKeys).go();
      });

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // v1 -> v2: add the durable Signal Protocol key-material tables so a
          // session survives a restart. No existing rows change.
          if (from < 2) {
            await m.createTable(signalIdentity);
            await m.createTable(signalPreKeys);
            await m.createTable(signalSignedPreKeys);
            await m.createTable(signalSessions);
            await m.createTable(signalSenderKeys);
            await m.createTable(signalTrustedKeys);
          }
        },
      );
}


