import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';

import '../gen/resilience/v1/event.pb.dart';
import 'identity_keys.dart';
import 'qr_codec.dart';

/// The PUBLIC identity payload of a Resilience user — the thing that is shared
/// (typically via QR) when adding a contact.
///
/// A contact is a cryptographic identity, never a phone number. This card
/// carries only public material: the Ed25519 signing public key, the X25519
/// key-agreement public key, a human display name, and the derived
/// [resilienceId]. It is encoded with the versioned [IdentityCertificateBody]
/// protobuf for a compact, forward-compatible wire format.
class IdentityCard {
  IdentityCard({
    required this.signingPublicKey,
    required this.keyAgreementPublicKey,
    required this.displayName,
    required this.resilienceId,
    this.validFromMs,
    this.validUntilMs,
  });

  /// Raw Ed25519 signing public key.
  final Uint8List signingPublicKey;

  /// Raw X25519 key-agreement public key.
  final Uint8List keyAgreementPublicKey;

  /// Human-chosen display name.
  final String displayName;

  /// Deterministic human-facing identifier derived from [signingPublicKey].
  final String resilienceId;

  /// Optional validity window start (epoch millis).
  final int? validFromMs;

  /// Optional validity window end (epoch millis).
  final int? validUntilMs;

  /// Build a card from the device's own [IdentityKeys].
  factory IdentityCard.fromIdentityKeys(
    IdentityKeys keys, {
    required String displayName,
    int? validFromMs,
    int? validUntilMs,
  }) {
    return IdentityCard(
      signingPublicKey: Uint8List.fromList(keys.signingPublicKey),
      keyAgreementPublicKey: Uint8List.fromList(keys.keyAgreementPublicKey),
      displayName: displayName,
      resilienceId: keys.resilienceId,
      validFromMs: validFromMs,
      validUntilMs: validUntilMs,
    );
  }

  /// Serialize to the compact protobuf wire form.
  Uint8List toBytes() {
    final body = IdentityCertificateBody(
      signingPubkey: signingPublicKey,
      keyAgreementPubkey: keyAgreementPublicKey,
      displayName: displayName,
      resilienceId: resilienceId,
    );
    if (validFromMs != null) body.validFromMs = Int64(validFromMs!);
    if (validUntilMs != null) body.validUntilMs = Int64(validUntilMs!);
    return body.writeToBuffer();
  }

  /// Parse a card from protobuf wire bytes.
  factory IdentityCard.fromBytes(List<int> bytes) {
    final body = IdentityCertificateBody.fromBuffer(bytes);
    return IdentityCard(
      signingPublicKey: Uint8List.fromList(body.signingPubkey),
      keyAgreementPublicKey: Uint8List.fromList(body.keyAgreementPubkey),
      displayName: body.displayName,
      resilienceId: body.resilienceId,
      validFromMs: body.hasValidFromMs() ? body.validFromMs.toInt() : null,
      validUntilMs: body.hasValidUntilMs() ? body.validUntilMs.toInt() : null,
    );
  }

  /// Encode as a QR payload string (tagged as [QrKind.identity]).
  String toQrPayload() => encodeQr(QrKind.identity, toBytes());

  /// Decode an [IdentityCard] from a QR payload produced by [toQrPayload].
  ///
  /// Throws [QrCodecException] if the payload is malformed or not an identity
  /// QR.
  factory IdentityCard.fromQrPayload(String payload) {
    final decoded = decodeQr(payload);
    if (decoded.kind != QrKind.identity) {
      throw QrCodecException(
        'Expected identity QR but found ${decoded.kind.name}',
      );
    }
    return IdentityCard.fromBytes(decoded.payload);
  }

  /// Verify the derived [resilienceId] actually matches [signingPublicKey].
  /// Guards against a tampered card that pairs a key with someone else's ID.
  bool get hasConsistentResilienceId =>
      resilienceIdFromPubkey(signingPublicKey) == resilienceId;

  @override
  String toString() =>
      'IdentityCard($displayName, $resilienceId, '
      'signing=${base64Url.encode(signingPublicKey)})';

  @override
  bool operator ==(Object other) {
    if (other is! IdentityCard) return false;
    return displayName == other.displayName &&
        resilienceId == other.resilienceId &&
        _bytesEqual(signingPublicKey, other.signingPublicKey) &&
        _bytesEqual(keyAgreementPublicKey, other.keyAgreementPublicKey) &&
        validFromMs == other.validFromMs &&
        validUntilMs == other.validUntilMs;
  }

  @override
  int get hashCode => Object.hash(
        displayName,
        resilienceId,
        Object.hashAll(signingPublicKey),
        Object.hashAll(keyAgreementPublicKey),
        validFromMs,
        validUntilMs,
      );

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
