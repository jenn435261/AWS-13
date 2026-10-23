import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/sync/bloom.dart';

List<int> _id(int seed) {
  // Deterministic 32-byte "event id".
  final out = Uint8List(32);
  int x = seed * 2654435761 & 0xffffffff;
  for (int i = 0; i < 32; i++) {
    x = (x * 1103515245 + 12345) & 0xffffffff;
    out[i] = (x >> 16) & 0xff;
  }
  return out;
}

void main() {
  test('no false negatives: every inserted id reports contains == true', () {
    final ids = List.generate(500, _id);
    final filter = BloomFilter.build(ids);

    for (final id in ids) {
      expect(filter.contains(id), isTrue,
          reason: 'inserted id must always be reported present');
    }
  });

  test('absent ids are mostly reported absent (plausible FP rate)', () {
    final inserted = List.generate(500, _id);
    final filter = BloomFilter.build(inserted, bitsPerItem: 10);

    // Ids 100000.. were never inserted.
    final absent = List.generate(2000, (i) => _id(100000 + i));
    int falsePositives = 0;
    for (final id in absent) {
      if (filter.contains(id)) falsePositives++;
    }

    // With ~10 bits/item the theoretical FP rate is ~1%. Allow generous slack:
    // we only assert the filter is not degenerate (not everything collides).
    expect(falsePositives, lessThan(absent.length ~/ 5),
        reason: 'false-positive rate should be well under 20%');
  });

  test('round-trips through wire parts', () {
    final ids = List.generate(50, _id);
    final filter = BloomFilter.build(ids);

    final restored = BloomFilter.fromParts(
      bytes: filter.bytes,
      numHashes: filter.numHashes,
      numBits: filter.numBits,
    );

    for (final id in ids) {
      expect(restored.contains(id), isTrue);
    }
  });

  test('empty id set builds a valid, usable filter', () {
    final filter = BloomFilter.build(const <List<int>>[]);
    expect(filter.numBits, greaterThan(0));
    expect(filter.contains(_id(1)), isFalse);
  });
}
