import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Device identity key material for the Resilience Network.
///
/// Every device owns two long-lived keypairs:
///  * an **Ed25519 signing keypair** — proves authorship of events / certs,
///  * an **X25519 key-agreement keypair** — used for Diffie-Hellman key
///    exchange (the raw key-agreement public key is published in the identity
///    card; the Signal double-ratchet maintains its own ephemeral keys).
///
/// Private key bytes NEVER leave the device: this class merely holds them in
/// memory after they have been read from, or before they are written to, the
/// OS keystore (see [IdentityStore]).
class IdentityKeys {
  IdentityKeys({
    required this.signingPublicKey,
    required this.signingPrivateKey,
    required this.keyAgreementPublicKey,
    required this.keyAgreementPrivateKey,
  });

  /// Raw 32-byte Ed25519 public key.
  final Uint8List signingPublicKey;

  /// Raw 32-byte Ed25519 private seed.
  final Uint8List signingPrivateKey;

  /// Raw 32-byte X25519 public key.
  final Uint8List keyAgreementPublicKey;

  /// Raw 32-byte X25519 private key.
  final Uint8List keyAgreementPrivateKey;

  static final Ed25519 _ed25519 = Ed25519();
  static final X25519 _x25519 = X25519();

  /// The deterministic human-facing Resilience ID derived from the signing key.
  String get resilienceId => resilienceIdFromPubkey(signingPublicKey);

  /// Generate a brand-new pair of keypairs using a cryptographically secure
  /// random source (delegated to the `cryptography` package).
  static Future<IdentityKeys> generate() async {
    final signing = await _ed25519.newKeyPair();
    final signingPub = await signing.extractPublicKey();
    final signingPriv = await signing.extractPrivateKeyBytes();

    final agreement = await _x25519.newKeyPair();
    final agreementPub = await agreement.extractPublicKey();
    final agreementPriv = await agreement.extractPrivateKeyBytes();

    return IdentityKeys(
      signingPublicKey: Uint8List.fromList(signingPub.bytes),
      signingPrivateKey: Uint8List.fromList(signingPriv),
      keyAgreementPublicKey: Uint8List.fromList(agreementPub.bytes),
      keyAgreementPrivateKey: Uint8List.fromList(agreementPriv),
    );
  }

  /// Reconstruct an [IdentityKeys] from previously persisted raw bytes.
  ///
  /// Public keys are re-derived from the private keys so a corrupted public
  /// key on disk cannot silently poison the identity.
  static Future<IdentityKeys> fromPrivateBytes({
    required List<int> signingPrivateKey,
    required List<int> keyAgreementPrivateKey,
  }) async {
    final signing = await _ed25519.newKeyPairFromSeed(
      List<int>.from(signingPrivateKey),
    );
    final signingPub = await signing.extractPublicKey();

    final agreement = await _x25519.newKeyPairFromSeed(
      List<int>.from(keyAgreementPrivateKey),
    );
    final agreementPub = await agreement.extractPublicKey();

    return IdentityKeys(
      signingPublicKey: Uint8List.fromList(signingPub.bytes),
      signingPrivateKey: Uint8List.fromList(signingPrivateKey),
      keyAgreementPublicKey: Uint8List.fromList(agreementPub.bytes),
      keyAgreementPrivateKey: Uint8List.fromList(keyAgreementPrivateKey),
    );
  }

  /// Sign [message] with the Ed25519 signing private key.
  Future<Uint8List> sign(List<int> message) async {
    final keyPair = await _ed25519.newKeyPairFromSeed(
      List<int>.from(signingPrivateKey),
    );
    final signature = await _ed25519.sign(message, keyPair: keyPair);
    return Uint8List.fromList(signature.bytes);
  }

  /// Verify a detached Ed25519 [signature] over [message] against
  /// [signingPublicKey].
  static Future<bool> verify(
    List<int> message,
    List<int> signature,
    List<int> signingPublicKey,
  ) async {
    final sig = Signature(
      List<int>.from(signature),
      publicKey: SimplePublicKey(
        List<int>.from(signingPublicKey),
        type: KeyPairType.ed25519,
      ),
    );
    return _ed25519.verify(message, signature: sig);
  }
}

/// Crockford base-32 alphabet (no I, L, O, U — avoids visual ambiguity).
const String _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Number of hash bytes folded into the Resilience ID. 10 bytes => 80 bits of
/// collision resistance, which renders to 16 Crockford base-32 characters.
const int _resilienceIdHashBytes = 10;

/// Derive a human-facing **Resilience ID** from an Ed25519 public key.
///
/// Derivation (deterministic, versionless, dependency-free):
///   1. Compute BLAKE2b-256 of the raw Ed25519 public key.
///   2. Take the first [_resilienceIdHashBytes] (10) bytes of the digest.
///   3. Encode those bytes with Crockford base-32 (upper-case, ambiguity-free).
///   4. Group the 16 resulting characters into 4-char blocks separated by '-'.
///
/// The same public key always yields the same ID (stable), and different keys
/// yield different IDs with overwhelming probability. Example shape:
/// `A1B2-C3D4-E5F6-G7H8`.
String resilienceIdFromPubkey(List<int> ed25519Pub) {
  final digest = _blake2b256(Uint8List.fromList(ed25519Pub));
  final prefix = digest.sublist(0, _resilienceIdHashBytes);
  final encoded = _crockfordBase32(prefix);
  return _group(encoded, 4);
}

String _group(String s, int size) {
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i != 0 && i % size == 0) buffer.write('-');
    buffer.write(s[i]);
  }
  return buffer.toString();
}

/// Crockford base-32 encode of arbitrary bytes (no padding).
String _crockfordBase32(Uint8List bytes) {
  final out = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final b in bytes) {
    buffer = (buffer << 8) | b;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.write(_crockford[(buffer >> bits) & 0x1f]);
    }
  }
  if (bits > 0) {
    out.write(_crockford[(buffer << (5 - bits)) & 0x1f]);
  }
  return out.toString();
}

// ---------------------------------------------------------------------------
// Minimal, self-contained BLAKE2b-256 implementation.
//
// Deliberately local (not importing lib/core/hashing.dart) so the identity
// subsystem has no cross-module build dependency. RFC 7693 reference algorithm.
// ---------------------------------------------------------------------------

final List<List<int>> _blakeSigma = [
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
  [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
  [11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4],
  [7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8],
  [9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13],
  [2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9],
  [12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11],
  [13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10],
  [6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5],
  [10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0],
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
  [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
];

final List<BigInt> _blakeIv = <int>[
  0x6a09e667f3bcc908,
  0xbb67ae8584caa73b,
  0x3c6ef372fe94f82b,
  0xa54ff53a5f1d36f1,
  0x510e527fade682d1,
  0x9b05688c2b3e6c1f,
  0x1f83d9abfb41bd6b,
  0x5be0cd19137e2179,
].map((e) => BigInt.from(e).toUnsigned(64)).toList();

final BigInt _mask64 = (BigInt.one << 64) - BigInt.one;

BigInt _rotr64(BigInt x, int n) {
  return ((x >> n) | (x << (64 - n))) & _mask64;
}

Uint8List _blake2b256(Uint8List input) {
  const outLen = 32;
  final h = List<BigInt>.generate(8, (i) => _blakeIv[i]);
  // Parameter block: digest length in low byte, key length 0, fanout/depth 1.
  h[0] = h[0] ^ BigInt.from(0x01010000 ^ outLen);

  var counter = BigInt.zero;
  final blocks = <List<int>>[];
  for (var i = 0; i < input.length; i += 128) {
    final end = (i + 128 <= input.length) ? i + 128 : input.length;
    blocks.add(input.sublist(i, end));
  }
  if (blocks.isEmpty) blocks.add(<int>[]);

  for (var bi = 0; bi < blocks.length; bi++) {
    final isLast = bi == blocks.length - 1;
    final block = List<int>.filled(128, 0);
    for (var j = 0; j < blocks[bi].length; j++) {
      block[j] = blocks[bi][j];
    }
    counter += BigInt.from(blocks[bi].length);
    _blakeCompress(h, block, counter, isLast);
  }

  final out = Uint8List(outLen);
  for (var i = 0; i < outLen; i++) {
    final word = h[i ~/ 8];
    out[i] = ((word >> (8 * (i % 8))) & BigInt.from(0xff)).toInt();
  }
  return out;
}

void _blakeCompress(
  List<BigInt> h,
  List<int> block,
  BigInt counter,
  bool isLast,
) {
  final m = List<BigInt>.generate(16, (i) {
    var word = BigInt.zero;
    for (var j = 0; j < 8; j++) {
      word |= BigInt.from(block[i * 8 + j]) << (8 * j);
    }
    return word & _mask64;
  });

  final v = List<BigInt>.filled(16, BigInt.zero);
  for (var i = 0; i < 8; i++) {
    v[i] = h[i];
    v[i + 8] = _blakeIv[i];
  }
  v[12] = v[12] ^ (counter & _mask64);
  v[13] = v[13] ^ (counter >> 64);
  if (isLast) v[14] = v[14] ^ _mask64;

  void mix(int a, int b, int c, int d, BigInt x, BigInt y) {
    v[a] = (v[a] + v[b] + x) & _mask64;
    v[d] = _rotr64(v[d] ^ v[a], 32);
    v[c] = (v[c] + v[d]) & _mask64;
    v[b] = _rotr64(v[b] ^ v[c], 24);
    v[a] = (v[a] + v[b] + y) & _mask64;
    v[d] = _rotr64(v[d] ^ v[a], 16);
    v[c] = (v[c] + v[d]) & _mask64;
    v[b] = _rotr64(v[b] ^ v[c], 63);
  }

  for (var round = 0; round < 12; round++) {
    final s = _blakeSigma[round];
    mix(0, 4, 8, 12, m[s[0]], m[s[1]]);
    mix(1, 5, 9, 13, m[s[2]], m[s[3]]);
    mix(2, 6, 10, 14, m[s[4]], m[s[5]]);
    mix(3, 7, 11, 15, m[s[6]], m[s[7]]);
    mix(0, 5, 10, 15, m[s[8]], m[s[9]]);
    mix(1, 6, 11, 12, m[s[10]], m[s[11]]);
    mix(2, 7, 8, 13, m[s[12]], m[s[13]]);
    mix(3, 4, 9, 14, m[s[14]], m[s[15]]);
  }

  for (var i = 0; i < 8; i++) {
    h[i] = h[i] ^ v[i] ^ v[i + 8];
  }
}
