import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// Ed25519 digital signatures for event authentication.
///
/// Every event is signed by its author with Ed25519 over
/// (canonical header bytes WITH `event_id` set || body bytes). The signature is
/// 64 bytes; the `author_pubkey` in the header is the signer's 32-byte Ed25519
/// public key.
///
/// We use the pure-Dart [DartEd25519] implementation so behaviour is identical
/// across platforms and does not depend on a native backend being registered.

/// Raw, persistable Ed25519 keypair material.
///
/// * [publicKey] is the 32-byte Ed25519 public key (goes in the event header).
/// * [seed] is the 32-byte Ed25519 private seed. This is the value that must be
///   stored securely (e.g. the OS keystore) to reconstruct the keypair.
///
/// Ed25519 "private key" in RFC 8032 terms is the 32-byte seed; the expanded
/// scalar is derived from it. Persisting the seed is sufficient and standard.
class KeyPairData {
  final Uint8List publicKey;
  final Uint8List seed;

  KeyPairData({required this.publicKey, required this.seed})
      : assert(publicKey.length == 32, 'Ed25519 public key must be 32 bytes'),
        assert(seed.length == 32, 'Ed25519 seed must be 32 bytes');

  /// Reconstructs raw material from stored bytes (defensive copies).
  factory KeyPairData.fromBytes({
    required List<int> publicKey,
    required List<int> seed,
  }) =>
      KeyPairData(
        publicKey: Uint8List.fromList(publicKey),
        seed: Uint8List.fromList(seed),
      );
}

/// Thin wrapper around the Ed25519 primitives used by the event engine.
class Signer {
  final Ed25519 _algorithm;

  /// Creates a signer. By default uses the pure-Dart implementation, which is
  /// deterministic and platform-independent.
  Signer({Ed25519? algorithm}) : _algorithm = algorithm ?? DartEd25519();

  /// Generates a fresh Ed25519 keypair using a cryptographically secure RNG.
  Future<KeyPairData> generateKeyPair() async {
    final SimpleKeyPair kp = await _algorithm.newKeyPair();
    return _toKeyPairData(kp);
  }

  /// Rebuilds a keypair deterministically from a 32-byte [seed].
  Future<KeyPairData> keyPairFromSeed(List<int> seed) async {
    final SimpleKeyPair kp = await _algorithm.newKeyPairFromSeed(seed);
    return _toKeyPairData(kp);
  }

  Future<KeyPairData> _toKeyPairData(SimpleKeyPair kp) async {
    final SimpleKeyPairData data = await kp.extract();
    final SimplePublicKey pub = await kp.extractPublicKey();
    return KeyPairData(
      publicKey: Uint8List.fromList(pub.bytes),
      seed: Uint8List.fromList(data.bytes),
    );
  }

  /// Signs [message] with the private [keyPair], returning the raw 64-byte
  /// Ed25519 signature.
  Future<Uint8List> sign(KeyPairData keyPair, List<int> message) async {
    final SimpleKeyPair kp =
        await _algorithm.newKeyPairFromSeed(keyPair.seed);
    final Signature sig = await _algorithm.sign(message, keyPair: kp);
    return Uint8List.fromList(sig.bytes);
  }

  /// Verifies that [signature] (64 bytes) is a valid Ed25519 signature over
  /// [message] by the holder of [publicKey] (32 bytes).
  ///
  /// Returns `false` (never throws) on malformed inputs so callers can treat a
  /// bad signature and a malformed signature identically.
  Future<bool> verify(
    List<int> publicKey,
    List<int> message,
    List<int> signature,
  ) async {
    if (publicKey.length != 32 || signature.length != 64) {
      return false;
    }
    try {
      final Signature sig = Signature(
        signature,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      );
      return await _algorithm.verify(message, signature: sig);
    } catch (_) {
      return false;
    }
  }
}
