import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'identity_card.dart';
import 'identity_keys.dart';

/// Abstraction over secret persistence.
///
/// The real app backs this with the OS keystore / keychain
/// ([FlutterSecureSecretStore]). Unit tests use [InMemorySecretStore] because
/// `flutter_secure_storage` requires platform channels that are unavailable in
/// a pure-Dart `flutter test` VM.
abstract class SecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<bool> containsKey(String key);

  Future<void> delete(String key);
}

/// Production [SecretStore] backed by `flutter_secure_storage`, which maps to
/// the Android Keystore / iOS Keychain. Private keys persisted here never leave
/// the device.
class FlutterSecureSecretStore implements SecretStore {
  FlutterSecureSecretStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<bool> containsKey(String key) => _storage.containsKey(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// In-memory [SecretStore] for tests and ephemeral use.
class InMemorySecretStore implements SecretStore {
  final Map<String, String> _map = {};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;

  @override
  Future<bool> containsKey(String key) async => _map.containsKey(key);

  @override
  Future<void> delete(String key) async => _map.remove(key);
}

/// A loaded device identity: the key material plus the display name, and a
/// convenience [card] for sharing.
class DeviceIdentity {
  DeviceIdentity({required this.keys, required this.displayName});

  final IdentityKeys keys;
  final String displayName;

  String get resilienceId => keys.resilienceId;

  /// Build the public [IdentityCard] (what goes in a QR).
  IdentityCard get card =>
      IdentityCard.fromIdentityKeys(keys, displayName: displayName);
}

/// Persists and loads the device's long-lived identity key material through a
/// pluggable [SecretStore].
class IdentityStore {
  IdentityStore(this._secrets);

  final SecretStore _secrets;

  static const String _kSigningPriv = 'resilience.identity.signing_priv';
  static const String _kAgreementPriv = 'resilience.identity.agreement_priv';
  static const String _kDisplayName = 'resilience.identity.display_name';

  /// Load the existing device identity on repeat runs, or generate a brand-new
  /// one on first run and persist it. Subsequent calls return the SAME
  /// identity (same keys, same Resilience ID).
  ///
  /// [defaultDisplayName] is only used when creating a fresh identity.
  Future<DeviceIdentity> getOrCreateIdentity({
    String defaultDisplayName = 'Unnamed',
  }) async {
    final existing = await loadIdentity();
    if (existing != null) return existing;

    final keys = await IdentityKeys.generate();
    await _persist(keys, defaultDisplayName);
    return DeviceIdentity(keys: keys, displayName: defaultDisplayName);
  }

  /// Load the stored identity, or null if none has been created yet.
  Future<DeviceIdentity?> loadIdentity() async {
    final signingPrivB64 = await _secrets.read(_kSigningPriv);
    final agreementPrivB64 = await _secrets.read(_kAgreementPriv);
    if (signingPrivB64 == null || agreementPrivB64 == null) return null;

    final keys = await IdentityKeys.fromPrivateBytes(
      signingPrivateKey: base64Decode(signingPrivB64),
      keyAgreementPrivateKey: base64Decode(agreementPrivB64),
    );
    final displayName = await _secrets.read(_kDisplayName) ?? 'Unnamed';
    return DeviceIdentity(keys: keys, displayName: displayName);
  }

  /// Update the stored display name, keeping the keys intact.
  Future<void> setDisplayName(String displayName) async {
    await _secrets.write(_kDisplayName, displayName);
  }

  /// True if a device identity has already been created.
  Future<bool> hasIdentity() => _secrets.containsKey(_kSigningPriv);

  /// Remove all stored identity material (e.g. on factory reset).
  Future<void> clear() async {
    await _secrets.delete(_kSigningPriv);
    await _secrets.delete(_kAgreementPriv);
    await _secrets.delete(_kDisplayName);
  }

  Future<void> _persist(IdentityKeys keys, String displayName) async {
    await _secrets.write(
      _kSigningPriv,
      base64Encode(Uint8List.fromList(keys.signingPrivateKey)),
    );
    await _secrets.write(
      _kAgreementPriv,
      base64Encode(Uint8List.fromList(keys.keyAgreementPrivateKey)),
    );
    await _secrets.write(_kDisplayName, displayName);
  }
}
