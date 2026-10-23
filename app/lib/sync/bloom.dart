import 'dart:typed_data';

/// A simple, deterministic Bloom filter over event-id byte strings.
///
/// Used in the sync `HaveDigest` so a peer can cheaply probe which of our
/// advertised ids it probably already holds, without us transmitting the full
/// id set. A Bloom filter has no false negatives (if [contains] returns
/// `false`, the id was definitely never inserted) but may report false
/// positives (occasionally returns `true` for an absent id); the sync protocol
/// tolerates that because the per-author high-water diff is authoritative and
/// the Bloom is only an optimisation hint.
///
/// The construction is fully deterministic: the same ids and parameters always
/// produce the same bits and hash count, so two peers computing the same
/// digest agree bit-for-bit. Hashing uses FNV-1a with per-hash seeds derived by
/// the Kirsch–Mitzenmacher double-hashing scheme (h_i = h1 + i*h2), which is a
/// standard way to synthesise k hashes from two.
class BloomFilter {
  /// The filter bit array, packed 8 bits per byte.
  final Uint8List bytes;

  /// Number of hash functions (`k`).
  final int numHashes;

  /// Total number of addressable bits (`m`). Always == `bytes.length * 8`
  /// rounded up, but stored explicitly so it round-trips across the wire.
  final int numBits;

  const BloomFilter({
    required this.bytes,
    required this.numHashes,
    required this.numBits,
  });

  /// Builds a filter over [ids].
  ///
  /// [bitsPerItem] controls the bit budget per inserted id (the classic
  /// trade-off: more bits => fewer false positives). The number of hashes is
  /// derived as the theoretically optimal `round(bitsPerItem * ln2)`, clamped
  /// to at least 1. An empty id set still yields a valid (tiny) filter.
  factory BloomFilter.build(
    Iterable<List<int>> ids, {
    int bitsPerItem = 10,
  }) {
    final List<List<int>> items = ids.toList(growable: false);
    final int count = items.length;

    // Size the bit array. Guarantee a sane minimum so an empty/small set does
    // not produce a zero-length, unusable filter.
    int numBits = count * bitsPerItem;
    if (numBits < 64) numBits = 64;
    // Round up to a byte boundary.
    final int numBytes = (numBits + 7) ~/ 8;
    numBits = numBytes * 8;

    // Optimal k = (m/n) * ln2 ≈ bitsPerItem * 0.6931.
    int numHashes = (bitsPerItem * 0.6931471805599453).round();
    if (numHashes < 1) numHashes = 1;
    if (numHashes > 30) numHashes = 30;

    final Uint8List bytes = Uint8List(numBytes);
    final filter = BloomFilter(
      bytes: bytes,
      numHashes: numHashes,
      numBits: numBits,
    );
    for (final List<int> id in items) {
      filter._setFor(id);
    }
    return filter;
  }

  /// Reconstructs a filter from wire values.
  factory BloomFilter.fromParts({
    required List<int> bytes,
    required int numHashes,
    required int numBits,
  }) {
    return BloomFilter(
      bytes: Uint8List.fromList(bytes),
      numHashes: numHashes < 1 ? 1 : numHashes,
      numBits: numBits,
    );
  }

  void _setFor(List<int> id) {
    for (final int bit in _bitPositions(id)) {
      bytes[bit >> 3] |= (1 << (bit & 7));
    }
  }

  /// Whether [id] may be present. `false` is definitive (never inserted);
  /// `true` means "probably present" (could be a false positive).
  bool contains(List<int> id) {
    if (numBits == 0) return false;
    for (final int bit in _bitPositions(id)) {
      if ((bytes[bit >> 3] & (1 << (bit & 7))) == 0) {
        return false;
      }
    }
    return true;
  }

  Iterable<int> _bitPositions(List<int> id) sync* {
    final int m = numBits;
    final int h1 = _fnv1a(id, 0x811c9dc5);
    // A different seed gives an independent-ish second hash for double hashing.
    final int h2 = _fnv1a(id, 0xcbf29ce4) | 1; // ensure odd so steps cover ring
    for (int i = 0; i < numHashes; i++) {
      final int combined = (h1 + i * h2) & 0x7fffffff;
      yield combined % m;
    }
  }

  /// 32-bit FNV-1a over [data] starting from [seed].
  static int _fnv1a(List<int> data, int seed) {
    int h = seed & 0xffffffff;
    for (final int b in data) {
      h ^= (b & 0xff);
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }
}
