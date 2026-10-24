import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/hashing.dart' as hashing;

/// Pairing + per-session key derivation for the BLE GATT transport (spec §6.2).
///
/// Before two phones trust a BLE link they run a short pairing step. The goal
/// is to defeat a man-in-the-middle on the (unauthenticated) radio: both sides
/// derive the SAME 6-digit short authentication string from BOTH parties'
/// long-term identity public keys, and the humans compare them (or one scans
/// the other's identity QR, which carries the same public keys). If the codes
/// match, the keys each side sees are the keys the other side actually holds,
/// so the link is bound to those identities.
///
/// The per-session encryption key is an X25519 ECDH over the two identity
/// key-agreement public keys, run through HKDF-SHA256 with a transport-specific
/// info string. Both sides derive the same 32-byte key; neither key leaves the
/// device. This is layered ON TOP of the already-signed events — it protects
/// the sync framing on the wire; event authenticity is still the Ed25519
/// signature checked by EventStore.apply.
class BlePairing {
  BlePairing._();

  /// Number of decimal digits in the pairing code.
  static const int codeDigits = 6;

  static final X25519 _x25519 = X25519();
  static final Hkdf _hkdf =
      Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Derives the 6-digit pairing code from both parties' long-term signing
  /// public keys. Order-independent (the two keys are sorted first) so both
  /// sides compute the same value regardless of who is central/peripheral.
  ///
  /// The code is `BLAKE2b-256(sorted(keyA, keyB))` reduced to 6 decimal digits.
  /// A MITM that substitutes its own keys produces a different code, which the
  /// humans will see does not match.
  static String pairingCode(
    List<int> signingPubA,
    List<int> signingPubB,
  ) {
    final a = Uint8List.fromList(signingPubA);
    final b = Uint8List.fromList(signingPubB);
    final (first, second) = _sortPair(a, b);
    final digest = hashing.blake2b256(<int>[...first, ...second]);
    // Fold the first 4 bytes into an unsigned 32-bit int, then mod 1e6.
    final n = (digest[0] << 24) |
        (digest[1] << 16) |
        (digest[2] << 8) |
        digest[3];
    final code = (n & 0x7fffffff) % 1000000;
    return code.toString().padLeft(codeDigits, '0');
  }

  /// Whether two independently-computed pairing codes match (constant-ish time
  /// is unnecessary here — the code is public to both legitimate parties).
  static bool codesMatch(String a, String b) => a == b;

  /// Derives the shared 32-byte session key from this device's X25519 private
  /// key and the peer's X25519 public key. Both sides derive the same key.
  ///
  /// The HKDF salt is the sorted pair of public keys so the key is bound to the
  /// specific identities (and so a replay with swapped keys yields a different
  /// key). [info] namespaces the key to this transport/version.
  static Future<Uint8List> deriveSessionKey({
    required List<int> myKeyAgreementPrivateKey,
    required List<int> peerKeyAgreementPublicKey,
    required List<int> myKeyAgreementPublicKey,
    List<int> info = const <int>[],
  }) async {
    final myKp = await _x25519.newKeyPairFromSeed(
      List<int>.from(myKeyAgreementPrivateKey),
    );
    final peerPub = SimplePublicKey(
      List<int>.from(peerKeyAgreementPublicKey),
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: myKp,
      remotePublicKey: peerPub,
    );
    final sharedBytes = await shared.extractBytes();

    final (first, second) = _sortPair(
      Uint8List.fromList(myKeyAgreementPublicKey),
      Uint8List.fromList(peerKeyAgreementPublicKey),
    );
    final salt = Uint8List.fromList(<int>[...first, ...second]);

    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(sharedBytes),
      nonce: salt,
      info: info.isEmpty ? _defaultInfo : info,
    );
    return Uint8List.fromList(await derived.extractBytes());
  }

  static final List<int> _defaultInfo =
      Uint8List.fromList('resilience-ble-session-v1'.codeUnits);

  static (Uint8List, Uint8List) _sortPair(Uint8List a, Uint8List b) {
    return _lessOrEqual(a, b) ? (a, b) : (b, a);
  }

  static bool _lessOrEqual(Uint8List a, Uint8List b) {
    final n = a.length < b.length ? a.length : b.length;
    for (int i = 0; i < n; i++) {
      if (a[i] != b[i]) return a[i] < b[i];
    }
    return a.length <= b.length;
  }
}
