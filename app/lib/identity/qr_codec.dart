import 'dart:convert';
import 'dart:typed_data';

/// The semantic kind of a Resilience QR payload. The numeric [wire] value is
/// part of the on-wire format and MUST remain stable across releases.
enum QrKind {
  identity(1),
  mission(2),
  package(3),
  capability(4);

  const QrKind(this.wire);

  /// Stable numeric tag written into the QR payload.
  final int wire;

  static QrKind fromWire(int wire) {
    for (final k in QrKind.values) {
      if (k.wire == wire) return k;
    }
    throw QrCodecException('Unknown QrKind wire tag: $wire');
  }
}

/// Thrown when a QR payload cannot be decoded (malformed, wrong magic,
/// unsupported version, or unknown kind).
class QrCodecException implements Exception {
  QrCodecException(this.message);

  final String message;

  @override
  String toString() => 'QrCodecException: $message';
}

/// Decoded QR result: the [kind] and the opaque [payload] bytes.
class DecodedQr {
  DecodedQr(this.kind, this.payload);

  final QrKind kind;
  final Uint8List payload;
}

/// Pure-Dart codec for Resilience QR payloads.
///
/// Wire layout (before base64url): `[MAGIC 'R'][VERSION 1][KIND][payload...]`.
/// Everything is then base64url-encoded (no padding) so it fits cleanly inside
/// a QR code and is copy/paste friendly. The format is deliberately generic so
/// it serves identity cards today and mission / package / capability logistics
/// QRs later.
class QrCodec {
  QrCodec._();

  /// ASCII 'R' — guards against decoding arbitrary base64 as a Resilience QR.
  static const int _magic = 0x52;

  /// Current container version.
  static const int _version = 1;

  /// Encode [payload] tagged with [kind] into a transportable QR string.
  static String encodeQr(QrKind kind, Uint8List payload) {
    final framed = Uint8List(3 + payload.length)
      ..[0] = _magic
      ..[1] = _version
      ..[2] = kind.wire;
    framed.setRange(3, framed.length, payload);
    return base64Url.encode(framed);
  }

  /// Decode a QR string previously produced by [encodeQr].
  ///
  /// Throws [QrCodecException] on any malformed input.
  static DecodedQr decodeQr(String encoded) {
    if (encoded.isEmpty) {
      throw QrCodecException('Empty QR payload');
    }
    Uint8List framed;
    try {
      framed = base64Url.decode(_normalizeBase64(encoded));
    } on FormatException catch (e) {
      throw QrCodecException('Invalid base64url: ${e.message}');
    }
    if (framed.length < 3) {
      throw QrCodecException('QR payload too short: ${framed.length} bytes');
    }
    if (framed[0] != _magic) {
      throw QrCodecException(
        'Bad magic byte: 0x${framed[0].toRadixString(16)}',
      );
    }
    if (framed[1] != _version) {
      throw QrCodecException('Unsupported QR version: ${framed[1]}');
    }
    final kind = QrKind.fromWire(framed[2]);
    final payload = Uint8List.fromList(framed.sublist(3));
    return DecodedQr(kind, payload);
  }

  /// base64url strings may be presented with or without '=' padding; normalise
  /// so both forms decode cleanly.
  static String _normalizeBase64(String input) {
    final remainder = input.length % 4;
    if (remainder == 0) return input;
    return input + ('=' * (4 - remainder));
  }
}

/// Top-level convenience wrappers matching the subsystem spec.
String encodeQr(QrKind kind, Uint8List payload) =>
    QrCodec.encodeQr(kind, payload);

DecodedQr decodeQr(String encoded) => QrCodec.decodeQr(encoded);
