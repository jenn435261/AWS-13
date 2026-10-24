import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import '../core/hashing.dart';

/// The ciphertext of an encrypted attachment plus its random key.
///
/// Wire layout of [ciphertext]: `[12-byte nonce][AES-GCM ciphertext+tag]`. The
/// content address stored in the blob store is `sha256(ciphertext)`.
class EncryptedBlob {
  EncryptedBlob({required this.ciphertext, required this.key});

  final Uint8List ciphertext;
  final Uint8List key;

  /// Lowercase hex SHA-256 of the ciphertext — the content address.
  String get sha256Hex => _sha256Hex(ciphertext);
}

final AesGcm _aesGcm = AesGcm.with256bits();

/// Encrypt [plaintext] with a freshly-generated random 256-bit key using
/// AES-GCM. The key is returned so it can be embedded in the E2E message; it is
/// never uploaded. A random 12-byte nonce is prepended to the ciphertext.
Future<EncryptedBlob> encryptAttachment(List<int> plaintext) async {
  final secretKey = await _aesGcm.newSecretKey();
  final keyBytes = Uint8List.fromList(await secretKey.extractBytes());
  final nonce = _aesGcm.newNonce();
  final box = await _aesGcm.encrypt(plaintext, secretKey: secretKey, nonce: nonce);
  final out = Uint8List(nonce.length + box.cipherText.length + box.mac.bytes.length)
    ..setRange(0, nonce.length, nonce)
    ..setRange(nonce.length, nonce.length + box.cipherText.length, box.cipherText)
    ..setRange(nonce.length + box.cipherText.length, nonce.length + box.cipherText.length + box.mac.bytes.length,
        box.mac.bytes);
  return EncryptedBlob(ciphertext: out, key: keyBytes);
}

/// Thrown when an attachment fails to decrypt or fails its sha256 check.
class AttachmentException implements Exception {
  const AttachmentException(this.message);
  final String message;
  @override
  String toString() => 'AttachmentException: $message';
}

/// Decrypt [ciphertext] (nonce-prefixed AES-GCM) with [key], after verifying
/// that `sha256(ciphertext)` equals [expectedSha256]. A tampered blob (wrong
/// hash) or a tampered key/tag (GCM auth failure) raises
/// [AttachmentException] and is never returned to the UI.
Future<Uint8List> decryptAttachment(
  Uint8List ciphertext, {
  required Uint8List key,
  required String expectedSha256,
}) async {
  if (_sha256Hex(ciphertext) != expectedSha256) {
    throw const AttachmentException('attachment hash mismatch');
  }
  const nonceLen = 12;
  const macLen = 16;
  if (ciphertext.length < nonceLen + macLen) {
    throw const AttachmentException('attachment too short');
  }
  final nonce = ciphertext.sublist(0, nonceLen);
  final mac = ciphertext.sublist(ciphertext.length - macLen);
  final body = ciphertext.sublist(nonceLen, ciphertext.length - macLen);
  final secretKey = SecretKey(key);
  try {
    final clear = await _aesGcm.decrypt(
      SecretBox(body, nonce: nonce, mac: Mac(mac)),
      secretKey: secretKey,
    );
    return Uint8List.fromList(clear);
  } on SecretBoxAuthenticationError {
    throw const AttachmentException('attachment authentication failed');
  }
}

/// Lowercase hex SHA-256 of [bytes]. Blobs are addressed by sha256 to match the
/// Go blob endpoints (/v1/blobs/{sha256}); event ids use blake2b elsewhere.
const DartSha256 _dartSha256 = DartSha256();

String _sha256Hex(List<int> bytes) =>
    hashHex(Uint8List.fromList(_dartSha256.hashSync(bytes).bytes));
