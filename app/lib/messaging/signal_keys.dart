import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../gen/resilience/v1/event.pb.dart';

/// Install-time Signal Protocol key material for a device.
///
/// On first install each device generates:
///  * an **identity keypair** (long-term, authenticates the device in X3DH),
///  * a **registration id** (routing / session scoping),
///  * one **signed prekey** (medium-term, signed by the identity key),
///  * a batch of **one-time prekeys** (consumed one per inbound X3DH session).
///
/// This is the vetted libsignal_protocol_dart machinery — we never invent
/// crypto. [toPrekeyBundleBody] exports a single publishable
/// [PrekeyBundleBody] (identity key + registration id + signed prekey + one
/// one-time prekey) for the directory / sync layer.
class SignalKeys {
  SignalKeys({
    required this.identityKeyPair,
    required this.registrationId,
    required this.signedPreKey,
    required this.preKeys,
  });

  final IdentityKeyPair identityKeyPair;
  final int registrationId;
  final SignedPreKeyRecord signedPreKey;
  final List<PreKeyRecord> preKeys;

  /// Generate a complete install-time key set.
  ///
  /// [preKeyStart] is the first one-time prekey id, [preKeyCount] how many to
  /// mint, [signedPreKeyId] the id for the single signed prekey.
  static Future<SignalKeys> generate({
    int preKeyStart = 1,
    int preKeyCount = 110,
    int signedPreKeyId = 0,
  }) async {
    final identityKeyPair = generateIdentityKeyPair();
    final registrationId = generateRegistrationId(false);
    final preKeys = generatePreKeys(preKeyStart, preKeyCount);
    final signedPreKey = generateSignedPreKey(identityKeyPair, signedPreKeyId);
    return SignalKeys(
      identityKeyPair: identityKeyPair,
      registrationId: registrationId,
      signedPreKey: signedPreKey,
      preKeys: preKeys,
    );
  }

  /// Install this device's key material into an in-memory protocol store and
  /// return it. Later waves swap this for a Drift-backed store.
  Future<InMemorySignalProtocolStore> buildStore() async {
    final store =
        InMemorySignalProtocolStore(identityKeyPair, registrationId);
    for (final p in preKeys) {
      await store.storePreKey(p.id, p);
    }
    await store.storeSignedPreKey(signedPreKey.id, signedPreKey);
    return store;
  }

  /// Export a publishable prekey bundle. By default it advertises the first
  /// one-time prekey; pass [oneTimePreKeyIndex] to pick another from [preKeys].
  PrekeyBundleBody toPrekeyBundleBody({int oneTimePreKeyIndex = 0}) {
    if (preKeys.isEmpty) {
      throw StateError('No one-time prekeys available to publish');
    }
    final oneTime = preKeys[oneTimePreKeyIndex];
    return PrekeyBundleBody(
      identityPubkey: identityKeyPair.getPublicKey().serialize(),
      registrationId: registrationId,
      signedPrekeyId: signedPreKey.id,
      signedPrekeyPub: signedPreKey.getKeyPair().publicKey.serialize(),
      signedPrekeySig: signedPreKey.signature,
      prekeyId: oneTime.id,
      prekeyPub: oneTime.getKeyPair().publicKey.serialize(),
    );
  }

  /// Reconstruct a libsignal [PreKeyBundle] from a published
  /// [PrekeyBundleBody]. This is what the *remote* party is given so they can
  /// initiate a session (X3DH) toward this device.
  ///
  /// [deviceId] is the recipient device id (1 for a single-device user).
  static PreKeyBundle preKeyBundleFromBody(
    PrekeyBundleBody body, {
    int deviceId = 1,
  }) {
    final identityKey = IdentityKey.fromBytes(
      Uint8List.fromList(body.identityPubkey),
      0,
    );
    final signedPreKeyPublic = Curve.decodePoint(
      Uint8List.fromList(body.signedPrekeyPub),
      0,
    );
    final preKeyPublic = body.hasPrekeyPub()
        ? Curve.decodePoint(Uint8List.fromList(body.prekeyPub), 0)
        : null;
    return PreKeyBundle(
      body.registrationId,
      deviceId,
      body.hasPrekeyId() ? body.prekeyId : null,
      preKeyPublic,
      body.signedPrekeyId,
      signedPreKeyPublic,
      Uint8List.fromList(body.signedPrekeySig),
      identityKey,
    );
  }
}
