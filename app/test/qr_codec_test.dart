import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/identity/qr_codec.dart';

void main() {
  group('QrCodec round-trips', () {
    for (final kind in QrKind.values) {
      test('round-trips for ${kind.name}', () {
        final payload = Uint8List.fromList(
          List<int>.generate(37, (i) => (i * 7 + kind.wire) % 256),
        );
        final encoded = encodeQr(kind, payload);
        final decoded = decodeQr(encoded);
        expect(decoded.kind, equals(kind));
        expect(decoded.payload, equals(payload));
      });
    }

    test('round-trips empty payload', () {
      final encoded = encodeQr(QrKind.capability, Uint8List(0));
      final decoded = decodeQr(encoded);
      expect(decoded.kind, QrKind.capability);
      expect(decoded.payload, isEmpty);
    });

    test('each kind encodes to a distinct string for same payload', () {
      final payload = Uint8List.fromList([1, 2, 3, 4]);
      final strings = QrKind.values.map((k) => encodeQr(k, payload)).toSet();
      expect(strings.length, QrKind.values.length);
    });
  });

  group('QrCodec malformed input', () {
    test('empty string throws', () {
      expect(() => decodeQr(''), throwsA(isA<QrCodecException>()));
    });

    test('non-base64 garbage throws', () {
      expect(() => decodeQr('@@@not base64@@@'), throwsA(isA<QrCodecException>()));
    });

    test('too-short framed payload throws', () {
      // base64url of a single byte -> framed length < 3.
      final shortEncoded = _b64url(Uint8List.fromList([0x52]));
      expect(() => decodeQr(shortEncoded), throwsA(isA<QrCodecException>()));
    });

    test('bad magic byte throws', () {
      final framed = Uint8List.fromList([0x00, 0x01, QrKind.identity.wire, 9]);
      expect(() => decodeQr(_b64url(framed)), throwsA(isA<QrCodecException>()));
    });

    test('unsupported version throws', () {
      final framed = Uint8List.fromList([0x52, 0x99, QrKind.identity.wire, 9]);
      expect(() => decodeQr(_b64url(framed)), throwsA(isA<QrCodecException>()));
    });

    test('unknown kind tag throws', () {
      final framed = Uint8List.fromList([0x52, 0x01, 0x7f, 9]);
      expect(() => decodeQr(_b64url(framed)), throwsA(isA<QrCodecException>()));
    });

    test('QrKind.fromWire rejects unknown tag', () {
      expect(() => QrKind.fromWire(999), throwsA(isA<QrCodecException>()));
    });
  });
}

String _b64url(Uint8List bytes) {
  // Mirror the codec's own base64url (no padding) choice.
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  final out = StringBuffer();
  var i = 0;
  while (i + 3 <= bytes.length) {
    final n = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
    out
      ..write(chars[(n >> 18) & 63])
      ..write(chars[(n >> 12) & 63])
      ..write(chars[(n >> 6) & 63])
      ..write(chars[n & 63]);
    i += 3;
  }
  final rem = bytes.length - i;
  if (rem == 1) {
    final n = bytes[i] << 16;
    out..write(chars[(n >> 18) & 63])..write(chars[(n >> 12) & 63]);
  } else if (rem == 2) {
    final n = (bytes[i] << 16) | (bytes[i + 1] << 8);
    out
      ..write(chars[(n >> 18) & 63])
      ..write(chars[(n >> 12) & 63])
      ..write(chars[(n >> 6) & 63]);
  }
  return out.toString();
}
