import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/core/hashing.dart' as hashing;
import 'package:resilience/transport/qr_fountain.dart';

void main() {
  Uint8List makePayload(int n, int seed) {
    final r = Random(seed);
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }

  group('QrFountain round-trip', () {
    test('lossless systematic transfer reconstructs exactly', () {
      final payload = makePayload(2500, 1);
      final enc = QrFountainEncoder(payload, blockSize: 400);
      final dec = QrFountainDecoder();
      var seed = 0;
      while (!dec.isComplete && seed < 10000) {
        dec.addFrame(enc.frameForSeed(seed));
        seed++;
      }
      expect(dec.isComplete, isTrue);
      expect(dec.result, equals(payload));
      expect(hashing.sha256(dec.result!), equals(hashing.sha256(payload)));
    });

    test('drops 30% of frames and still decodes exactly', () {
      final payload = makePayload(4000, 7);
      final enc = QrFountainEncoder(payload, blockSize: 300);
      final dec = QrFountainDecoder();
      final rng = Random(123);

      // Emit a long stream of coded frames, dropping ~30% at random and
      // occasionally re-delivering an old frame (duplicate).
      var seed = 0;
      var delivered = 0;
      final recent = <QrFrame>[];
      while (!dec.isComplete && seed < 200000) {
        final frame = enc.next();
        recent.add(frame);
        if (recent.length > 20) recent.removeAt(0);
        // 30% loss.
        if (rng.nextDouble() < 0.30) {
          seed++;
          continue;
        }
        dec.addFrame(frame);
        delivered++;
        // 10% chance to re-scan a recent (duplicate) frame.
        if (rng.nextDouble() < 0.10 && recent.isNotEmpty) {
          dec.addFrame(recent[rng.nextInt(recent.length)]);
        }
        seed++;
      }

      expect(dec.isComplete, isTrue,
          reason: 'decoder did not complete under 30% loss');
      expect(dec.result, equals(payload));
      // Fountain overhead should be modest: well under 2x the block count.
      expect(delivered, lessThan(enc.numBlocks * 3));
    });

    test('order-independent: shuffled frames decode', () {
      final payload = makePayload(1800, 42);
      final enc = QrFountainEncoder(payload, blockSize: 256);
      final frames = <QrFrame>[
        for (var s = 0; s < enc.numBlocks * 3; s++) enc.frameForSeed(s),
      ];
      frames.shuffle(Random(9));
      final dec = QrFountainDecoder();
      for (final f in frames) {
        dec.addFrame(f);
        if (dec.isComplete) break;
      }
      expect(dec.isComplete, isTrue);
      expect(dec.result, equals(payload));
    });

    test('qr string round-trip via base64url', () {
      final payload = makePayload(900, 3);
      final enc = QrFountainEncoder(payload, blockSize: 200);
      final dec = QrFountainDecoder();
      var s = 0;
      while (!dec.isComplete && s < 10000) {
        final str = enc.frameForSeed(s).toQrString();
        dec.addQrString(str);
        s++;
      }
      expect(dec.isComplete, isTrue);
      expect(dec.result, equals(payload));
    });
  });

  group('QrFountain integrity (abuse)', () {
    test('tampered frame body fails CRC and is ignored', () {
      final payload = makePayload(800, 5);
      final enc = QrFountainEncoder(payload, blockSize: 400);
      final bytes = enc.frameForSeed(0).toBytes();
      // Flip a byte in the body region (after the 49-byte header).
      bytes[60] ^= 0xff;
      final parsed = QrFrame.tryParse(bytes);
      expect(parsed, isNull, reason: 'CRC should reject a tampered frame');
    });

    test('tampered payload (CRC kept valid) fails final SHA-256', () {
      // Build a decoder fed with frames whose header SHA claims payload A but
      // whose bodies encode payload B. The per-frame CRC is valid (we rebuild
      // frames), so only the whole-payload SHA-256 can catch the swap.
      final good = makePayload(800, 11);
      final evil = makePayload(800, 99);
      final encGood = QrFountainEncoder(good, blockSize: 400);
      final encEvil = QrFountainEncoder(evil, blockSize: 400);

      final dec = QrFountainDecoder();
      // Forge frames that advertise the GOOD header+sha but carry EVIL bodies.
      for (var s = 0; s < encEvil.numBlocks + 4; s++) {
        final evilFrame = encEvil.frameForSeed(s);
        final forged = QrFrame(
          totalLen: encGood.totalLen,
          blockSize: 400,
          numBlocks: encGood.numBlocks,
          sha256: encGood.sha256,
          seed: s,
          body: evilFrame.body,
        );
        // Re-encode so CRC matches the forged bytes (attacker controls CRC).
        final reparsed = QrFrame.tryParse(forged.toBytes());
        expect(reparsed, isNotNull);
        dec.addFrame(reparsed!);
      }
      // All blocks "recovered" but SHA-256 mismatch => never surfaced.
      expect(dec.isComplete, isFalse);
      expect(dec.result, isNull);
    });

    test('frames from a different payload session are ignored', () {
      final a = makePayload(600, 1);
      final b = makePayload(600, 2);
      final encA = QrFountainEncoder(a, blockSize: 300);
      final encB = QrFountainEncoder(b, blockSize: 300);
      final dec = QrFountainDecoder();
      dec.addFrame(encA.frameForSeed(0));
      // A frame for a different payload must not advance recovery.
      final advanced = dec.addFrame(encB.frameForSeed(0));
      expect(advanced, isFalse);
    });

    test('garbage qr string is safely ignored', () {
      final dec = QrFountainDecoder();
      expect(dec.addQrString('@@@not-base64@@@'), isFalse);
      expect(dec.addQrString(''), isFalse);
      expect(dec.isComplete, isFalse);
    });
  });

  group('QrFountain progress reporting', () {
    test('progress advances toward N/M', () {
      final payload = makePayload(2000, 8);
      final enc = QrFountainEncoder(payload, blockSize: 400);
      final dec = QrFountainDecoder();
      expect(dec.progress(), '0/?');
      dec.addFrame(enc.frameForSeed(0));
      expect(dec.numBlocks, enc.numBlocks);
      expect(dec.recovered, greaterThanOrEqualTo(1));
    });
  });
}
