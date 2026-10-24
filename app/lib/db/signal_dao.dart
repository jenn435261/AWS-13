import 'package:drift/drift.dart';

import 'database.dart';

part 'signal_dao.g.dart';

/// Data-access object for durable Signal Protocol key material.
///
/// This is the persistence seam under [DriftSignalProtocolStore]: it reads and
/// writes the vetted libsignal record bytes (identity keypair, prekeys, signed
/// prekeys, sessions, sender keys, trusted remote identities). It never
/// interprets the bytes and never logs them.
@DriftAccessor(tables: [
  SignalIdentity,
  SignalPreKeys,
  SignalSignedPreKeys,
  SignalSessions,
  SignalSenderKeys,
  SignalTrustedKeys,
])
class SignalDao extends DatabaseAccessor<AppDatabase> with _$SignalDaoMixin {
  SignalDao(super.db);

  // --- identity (singleton row id = 0) ---

  Future<SignalIdentityData?> loadIdentity() =>
      (select(signalIdentity)..where((t) => t.id.equals(0))).getSingleOrNull();

  Future<void> saveIdentity(Uint8List keyPair, int registrationId) async {
    await into(signalIdentity).insertOnConflictUpdate(SignalIdentityCompanion(
      id: const Value(0),
      identityKeyPair: Value(keyPair),
      registrationId: Value(registrationId),
    ));
  }

  // --- one-time prekeys ---

  Future<List<SignalPreKey>> loadPreKeys() => select(signalPreKeys).get();

  Future<void> storePreKey(int id, Uint8List record) =>
      into(signalPreKeys).insertOnConflictUpdate(
          SignalPreKeysCompanion(preKeyId: Value(id), record: Value(record)));

  Future<void> removePreKey(int id) =>
      (delete(signalPreKeys)..where((t) => t.preKeyId.equals(id))).go();

  // --- signed prekeys ---

  Future<List<SignalSignedPreKey>> loadSignedPreKeys() =>
      select(signalSignedPreKeys).get();

  Future<void> storeSignedPreKey(int id, Uint8List record) =>
      into(signalSignedPreKeys).insertOnConflictUpdate(
          SignalSignedPreKeysCompanion(
              signedPreKeyId: Value(id), record: Value(record)));

  Future<void> removeSignedPreKey(int id) =>
      (delete(signalSignedPreKeys)..where((t) => t.signedPreKeyId.equals(id)))
          .go();

  // --- sessions ---

  Future<List<SignalSession>> loadSessions() => select(signalSessions).get();

  Future<void> storeSession(String address, Uint8List record) =>
      into(signalSessions).insertOnConflictUpdate(SignalSessionsCompanion(
          address: Value(address), record: Value(record)));

  Future<void> deleteSession(String address) =>
      (delete(signalSessions)..where((t) => t.address.equals(address))).go();

  // --- sender keys ---

  Future<List<SignalSenderKey>> loadSenderKeys() =>
      select(signalSenderKeys).get();

  Future<void> storeSenderKey(String name, Uint8List record) =>
      into(signalSenderKeys).insertOnConflictUpdate(SignalSenderKeysCompanion(
          senderKeyName: Value(name), record: Value(record)));

  // --- trusted remote identities ---

  Future<List<SignalTrustedKey>> loadTrustedKeys() =>
      select(signalTrustedKeys).get();

  Future<void> storeTrustedKey(String address, Uint8List key) =>
      into(signalTrustedKeys).insertOnConflictUpdate(SignalTrustedKeysCompanion(
          address: Value(address), identityKey: Value(key)));
}
