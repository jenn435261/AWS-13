import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../db/signal_dao.dart';

/// A durable [SignalProtocolStore] backed by Drift.
///
/// It keeps the fast in-memory libsignal stores hydrated from the database and
/// writes every mutation straight back to Drift, so a running X3DH/Double
/// Ratchet session (identity, prekeys, signed prekeys, sessions and group
/// sender keys) survives an app restart instead of being lost.
///
/// We never invent crypto: the persisted bytes are always the vetted libsignal
/// record's own `serialize()` output, re-hydrated with the matching
/// `fromSerialized`. Key material is never logged.
///
/// Create one with [DriftSignalProtocolStore.load], which reads any existing
/// material from [SignalDao] (and persists freshly-generated identity/prekeys
/// when none exist yet).
class DriftSignalProtocolStore implements SignalProtocolStore {
  DriftSignalProtocolStore._(this._dao, this._identityKeyPair,
      this._registrationId, this._trusted);

  final SignalDao _dao;
  final IdentityKeyPair _identityKeyPair;
  final int _registrationId;

  // In-memory mirrors (hydrated on load, kept in sync by write-through).
  final Map<int, Uint8List> _preKeys = <int, Uint8List>{};
  final Map<int, Uint8List> _signedPreKeys = <int, Uint8List>{};
  final Map<String, Uint8List> _sessions = <String, Uint8List>{};
  final Map<String, Uint8List> _senderKeys = <String, Uint8List>{};
  final Map<String, IdentityKey> _trusted;

  IdentityKeyPair get identityKeyPair => _identityKeyPair;
  int get registrationId => _registrationId;

  /// Load a durable store from [dao].
  ///
  /// If no identity exists yet, [onFirstRun] is invoked to generate the device
  /// key material (identity keypair + registration id + initial prekeys/signed
  /// prekey), which is then persisted. On subsequent runs the existing material
  /// is re-hydrated and [onFirstRun] is not called.
  static Future<DriftSignalProtocolStore> load(
    SignalDao dao, {
    required Future<FreshSignalKeys> Function() onFirstRun,
  }) async {
    var identity = await dao.loadIdentity();
    List<PreKeyRecord>? freshPreKeys;
    SignedPreKeyRecord? freshSigned;

    if (identity == null) {
      final fresh = await onFirstRun();
      await dao.saveIdentity(
        fresh.identityKeyPair.serialize(),
        fresh.registrationId,
      );
      freshPreKeys = fresh.preKeys;
      freshSigned = fresh.signedPreKey;
      identity = await dao.loadIdentity();
    }

    final identityKeyPair =
        IdentityKeyPair.fromSerialized(Uint8List.fromList(identity!.identityKeyPair));

    final trusted = <String, IdentityKey>{};
    for (final t in await dao.loadTrustedKeys()) {
      trusted[t.address] =
          IdentityKey.fromBytes(Uint8List.fromList(t.identityKey), 0);
    }

    final store = DriftSignalProtocolStore._(
      dao,
      identityKeyPair,
      identity.registrationId,
      trusted,
    );

    for (final p in await dao.loadPreKeys()) {
      store._preKeys[p.preKeyId] = Uint8List.fromList(p.record);
    }
    for (final sp in await dao.loadSignedPreKeys()) {
      store._signedPreKeys[sp.signedPreKeyId] = Uint8List.fromList(sp.record);
    }
    for (final s in await dao.loadSessions()) {
      store._sessions[s.address] = Uint8List.fromList(s.record);
    }
    for (final sk in await dao.loadSenderKeys()) {
      store._senderKeys[sk.senderKeyName] = Uint8List.fromList(sk.record);
    }

    // Persist freshly generated prekeys on first run.
    if (freshPreKeys != null) {
      for (final p in freshPreKeys) {
        await store.storePreKey(p.id, p);
      }
    }
    if (freshSigned != null) {
      await store.storeSignedPreKey(freshSigned.id, freshSigned);
    }

    return store;
  }

  static String _addr(SignalProtocolAddress a) =>
      '${a.getName()}::${a.getDeviceId()}';

  // --- IdentityKeyStore ---

  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async => _identityKeyPair;

  @override
  Future<int> getLocalRegistrationId() async => _registrationId;

  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async =>
      _trusted[_addr(address)];

  @override
  Future<bool> isTrustedIdentity(SignalProtocolAddress address,
      IdentityKey? identityKey, Direction? direction) async {
    if (identityKey == null) return false;
    final existing = _trusted[_addr(address)];
    if (existing == null) return true; // TOFU: trust on first use.
    return _bytesEqual(existing.serialize(), identityKey.serialize());
  }

  @override
  Future<bool> saveIdentity(
      SignalProtocolAddress address, IdentityKey? identityKey) async {
    if (identityKey == null) return false;
    final key = _addr(address);
    final existing = _trusted[key];
    if (existing != null &&
        _bytesEqual(existing.serialize(), identityKey.serialize())) {
      return false;
    }
    _trusted[key] = identityKey;
    await _dao.storeTrustedKey(key, identityKey.serialize());
    return true;
  }

  // --- PreKeyStore ---

  @override
  Future<PreKeyRecord> loadPreKey(int preKeyId) async {
    final bytes = _preKeys[preKeyId];
    if (bytes == null) {
      throw InvalidKeyIdException('No such prekey record: $preKeyId');
    }
    return PreKeyRecord.fromBuffer(bytes);
  }

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    final bytes = record.serialize();
    _preKeys[preKeyId] = bytes;
    await _dao.storePreKey(preKeyId, bytes);
  }

  @override
  Future<bool> containsPreKey(int preKeyId) async =>
      _preKeys.containsKey(preKeyId);

  @override
  Future<void> removePreKey(int preKeyId) async {
    _preKeys.remove(preKeyId);
    await _dao.removePreKey(preKeyId);
  }

  // --- SignedPreKeyStore ---

  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int signedPreKeyId) async {
    final bytes = _signedPreKeys[signedPreKeyId];
    if (bytes == null) {
      throw InvalidKeyIdException('No such signed prekey: $signedPreKeyId');
    }
    return SignedPreKeyRecord.fromSerialized(bytes);
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async =>
      _signedPreKeys.values
          .map((b) => SignedPreKeyRecord.fromSerialized(b))
          .toList();

  @override
  Future<void> storeSignedPreKey(
      int signedPreKeyId, SignedPreKeyRecord record) async {
    final bytes = record.serialize();
    _signedPreKeys[signedPreKeyId] = bytes;
    await _dao.storeSignedPreKey(signedPreKeyId, bytes);
  }

  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async =>
      _signedPreKeys.containsKey(signedPreKeyId);

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) async {
    _signedPreKeys.remove(signedPreKeyId);
    await _dao.removeSignedPreKey(signedPreKeyId);
  }

  // --- SessionStore ---

  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    final bytes = _sessions[_addr(address)];
    if (bytes == null) return SessionRecord();
    return SessionRecord.fromSerialized(bytes);
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    final ids = <int>[];
    for (final key in _sessions.keys) {
      final parts = key.split('::');
      if (parts.length == 2 && parts[0] == name) {
        final d = int.tryParse(parts[1]);
        if (d != null && d != 1) ids.add(d);
      }
    }
    return ids;
  }

  @override
  Future<void> storeSession(
      SignalProtocolAddress address, SessionRecord record) async {
    final key = _addr(address);
    final bytes = record.serialize();
    _sessions[key] = bytes;
    await _dao.storeSession(key, bytes);
  }

  @override
  Future<bool> containsSession(SignalProtocolAddress address) async =>
      _sessions.containsKey(_addr(address));

  @override
  Future<void> deleteSession(SignalProtocolAddress address) async {
    final key = _addr(address);
    _sessions.remove(key);
    await _dao.deleteSession(key);
  }

  @override
  Future<void> deleteAllSessions(String name) async {
    final toRemove =
        _sessions.keys.where((k) => k.split('::').first == name).toList();
    for (final k in toRemove) {
      _sessions.remove(k);
      await _dao.deleteSession(k);
    }
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A durable, Drift-backed group Sender-Key store.
class DriftSenderKeyStore implements SenderKeyStore {
  DriftSenderKeyStore(this._dao, this._cache);

  final SignalDao _dao;
  final Map<String, Uint8List> _cache;

  /// Load the sender-key store, hydrating its cache from [dao].
  static Future<DriftSenderKeyStore> load(SignalDao dao) async {
    final cache = <String, Uint8List>{};
    for (final sk in await dao.loadSenderKeys()) {
      cache[sk.senderKeyName] = Uint8List.fromList(sk.record);
    }
    return DriftSenderKeyStore(dao, cache);
  }

  @override
  Future<SenderKeyRecord> loadSenderKey(SenderKeyName senderKeyName) async {
    final bytes = _cache[senderKeyName.serialize()];
    if (bytes == null) return SenderKeyRecord();
    return SenderKeyRecord.fromSerialized(bytes);
  }

  @override
  Future<void> storeSenderKey(
      SenderKeyName senderKeyName, SenderKeyRecord record) async {
    final key = senderKeyName.serialize();
    final bytes = record.serialize();
    _cache[key] = bytes;
    await _dao.storeSenderKey(key, bytes);
  }
}

/// Freshly-generated device key material produced on first run.
class FreshSignalKeys {
  FreshSignalKeys({
    required this.identityKeyPair,
    required this.registrationId,
    required this.signedPreKey,
    required this.preKeys,
  });
  final IdentityKeyPair identityKeyPair;
  final int registrationId;
  final SignedPreKeyRecord signedPreKey;
  final List<PreKeyRecord> preKeys;
}
