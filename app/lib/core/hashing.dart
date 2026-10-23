import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// BLAKE2b-256 content hashing for event identity.
///
/// Event identity in the Resilience Network is a content hash: BLAKE2b-256 over
/// the canonical serialization of the header (without the `event_id` field)
/// concatenated with the body bytes. The resulting 32-byte digest *is* the
/// `event_id`.
///
/// Implementation notes:
/// * We use the `cryptography` package's [Blake2b] configured for an output
///   length of 32 bytes. BLAKE2b natively supports arbitrary digest lengths
///   from 1..64 bytes via its parameter block (the output length is mixed into
///   the initialization vector), so a 32-byte BLAKE2b is a first-class, well
///   defined construction — NOT a truncation of the 64-byte variant. This is
///   the canonical "BLAKE2b-256".
/// * We use the pure-Dart synchronous implementation ([DartBlake2b]) so hashing
///   is deterministic, dependency-free at runtime, and callable synchronously.

const int blake2bDigestLengthBytes = 32;

/// The synchronous pure-Dart BLAKE2b hasher configured for a 32-byte digest.
final DartBlake2b _blake2b256 =
    DartBlake2b(hashLengthInBytes: blake2bDigestLengthBytes);

/// Computes the BLAKE2b-256 (32-byte) digest of [data].
///
/// Deterministic and synchronous. Returns a freshly-allocated [Uint8List] of
/// exactly [blake2bDigestLengthBytes] (32) bytes.
Uint8List blake2b256(List<int> data) {
  final Hash hash = _blake2b256.hashSync(data);
  final Uint8List out = Uint8List.fromList(hash.bytes);
  assert(out.length == blake2bDigestLengthBytes,
      'BLAKE2b-256 must produce 32 bytes, got ${out.length}');
  return out;
}

/// Lowercase hex encoding of [bytes]. Handy for logging and map keys.
String hashHex(List<int> bytes) => convert.hex.encode(bytes);

/// Decodes a lowercase (or uppercase) hex [string] back to bytes.
Uint8List hexToBytes(String string) =>
    Uint8List.fromList(convert.hex.decode(string));
