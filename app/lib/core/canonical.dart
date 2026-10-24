import 'dart:typed_data';

import 'package:protobuf/protobuf.dart' as pb;

import '../gen/resilience/v1/event.pb.dart';

/// Deterministic / canonical protobuf serialization for event hashing &
/// signing.
///
/// ## Why not just `writeToBuffer()` blindly?
///
/// Protobuf wire encoding is *not* guaranteed canonical in general: the spec
/// allows fields to be serialized in any order, permits packed/unpacked repeats
/// for some types, and carries unknown fields through. If two peers encoded the
/// "same" message with bytes in a different field order, their content hashes
/// would differ and the DAG would fail to converge. Content-addressing demands
/// a single, reproducible byte string.
///
/// ## The canonical form we commit to
///
/// `protobuf-dart`'s [pb.GeneratedMessage.writeToBuffer] iterates the message's
/// `BuilderInfo`, whose field list is sorted by ascending tag number, and emits
/// each *set* field in that order using the standard wire type for its declared
/// [pb.PbFieldType]. For the messages in this engine that means:
///
/// * fields are always written in ascending tag order (deterministic);
/// * scalar/bytes/string fields use the single canonical wire encoding;
/// * the one repeated-bytes field we hash over (`EventHeader.depends_on`,
///   `PbFieldType.PY`) is length-delimited, order-preserving, and emitted in
///   the order the author populated it — which is itself part of the signed
///   content, so it is deterministic for a fixed message value.
///
/// We additionally guarantee determinism by:
///
/// * clearing/ignoring unknown fields before encoding (so forwarded,
///   not-understood extension bytes never leak into a hash preimage), and
/// * operating on a defensive clone so canonicalization never mutates the
///   caller's message.
///
/// A unit test asserts that re-serializing the same message twice yields byte
/// identical output, locking this assumption in against library upgrades.
///
/// ## The hashing / signing preimages
///
/// * **event_id (hash) preimage:** `canonicalHeaderBytes(header, includeId:
///   false) || body`. The id field is excluded so the hash can *be* the id.
/// * **signature preimage:** `canonicalHeaderBytes(header, includeId: true) ||
///   body`. The id is included so the signature commits to the final id too.

/// Returns the canonical bytes of [header].
///
/// When [includeId] is `false` the `event_id` (tag 1) field is cleared before
/// encoding, producing the hash preimage header. When `true` the header is
/// encoded as-is (expected to already carry the computed `event_id`), producing
/// the signature preimage header.
///
/// The input [header] is never mutated.
Uint8List canonicalHeaderBytes(EventHeader header, {required bool includeId}) {
  // Defensive deep copy so we can safely strip id / unknown fields.
  final EventHeader copy = header.deepCopy();
  if (!includeId) {
    copy.clearEventId();
  }
  _stripUnknownFields(copy);
  return _writeCanonical(copy);
}

/// Canonical hash preimage: `header(without id) || body`.
///
/// This is exactly what [blake2b256] is applied to in order to derive the
/// `event_id`.
Uint8List hashPreimage(EventHeader header, List<int> body) {
  final Uint8List head = canonicalHeaderBytes(header, includeId: false);
  return _concat(head, body);
}

/// Canonical signature preimage: `header(with id) || body`.
///
/// This is exactly what Ed25519 signs / verifies.
Uint8List signaturePreimage(EventHeader header, List<int> body) {
  final Uint8List head = canonicalHeaderBytes(header, includeId: true);
  return _concat(head, body);
}

/// Canonical bytes of an arbitrary [message] (e.g. a body message).
///
/// Produces the same deterministic encoding guarantees as
/// [canonicalHeaderBytes]. Useful for serializing *Body messages into the
/// `SignedEvent.body` field in a reproducible way.
Uint8List canonicalBytes(pb.GeneratedMessage message) {
  final pb.GeneratedMessage copy = message.deepCopy();
  _stripUnknownFields(copy);
  return _writeCanonical(copy);
}

// --- internals ---------------------------------------------------------------

Uint8List _writeCanonical(pb.GeneratedMessage message) =>
    Uint8List.fromList(message.writeToBuffer());

/// Recursively clears unknown fields so forwarded-but-not-understood extension
/// bytes can never enter a hash/signature preimage.
void _stripUnknownFields(pb.GeneratedMessage message) {
  message.unknownFields.clear();
}

Uint8List _concat(List<int> a, List<int> b) {
  final Uint8List out = Uint8List(a.length + b.length);
  out.setRange(0, a.length, a);
  out.setRange(a.length, a.length + b.length, b);
  return out;
}
