import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart' show GZipDecoder, ZstdDecoder;
import 'package:flutter/foundation.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

// Reads a PMTiles v3 archive: one file holding a whole region's map tiles,
// found by a small index at the front. Spec:
// https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md
//
// Only the header and the index are kept in memory; each tile is read from
// the file when the map needs it.

/// Random access to the bytes of an archive, from a file or from memory.
abstract class PmTilesSource {
  /// The [length] bytes starting at [offset].
  Future<Uint8List> read(int offset, int length);

  Future<void> close();
}

/// An archive held in memory, for tests and for the web preview.
class MemoryPmTilesSource implements PmTilesSource {
  MemoryPmTilesSource(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List> read(int offset, int length) async {
    if (offset < 0 || offset + length > bytes.length) {
      throw const PmTilesException('Read past the end of the map file');
    }
    return Uint8List.sublistView(bytes, offset, offset + length);
  }

  @override
  Future<void> close() async {}
}

/// The file is not a map this app can read.
class PmTilesException implements Exception {
  const PmTilesException(this.message);

  final String message;

  @override
  String toString() => 'PmTilesException: $message';
}

enum PmTilesCompression { unknown, none, gzip, brotli, zstd }

enum PmTilesTileType { unknown, mvt, png, jpeg, webp, avif }

/// The fixed 127 bytes at the start of every archive.
class PmTilesHeader {
  const PmTilesHeader({
    required this.rootOffset,
    required this.rootLength,
    required this.metadataOffset,
    required this.metadataLength,
    required this.leafOffset,
    required this.leafLength,
    required this.tileDataOffset,
    required this.tileDataLength,
    required this.internalCompression,
    required this.tileCompression,
    required this.tileType,
    required this.minZoom,
    required this.maxZoom,
    required this.bounds,
    required this.center,
    required this.centerZoom,
  });

  static const length = 127;

  /// Where the spec promises the header and root index fit.
  static const firstRead = 16384;

  final int rootOffset;
  final int rootLength;
  final int metadataOffset;
  final int metadataLength;
  final int leafOffset;
  final int leafLength;
  final int tileDataOffset;
  final int tileDataLength;
  final PmTilesCompression internalCompression;
  final PmTilesCompression tileCompression;
  final PmTilesTileType tileType;
  final int minZoom;
  final int maxZoom;

  /// West, south, east, north in degrees.
  final (double, double, double, double) bounds;

  /// Longitude, latitude in degrees.
  final (double, double) center;
  final int centerZoom;

  factory PmTilesHeader.parse(Uint8List bytes) {
    if (bytes.length < length || ascii.decode(bytes.sublist(0, 7), allowInvalid: true) != 'PMTiles') {
      throw const PmTilesException('Not a PMTiles map file');
    }
    if (bytes[7] != 3) {
      throw PmTilesException('PMTiles version ${bytes[7]} is not supported');
    }
    final data = ByteData.sublistView(bytes);
    int u64(int at) => _uint64(data, at);
    double e7(int at) => data.getInt32(at, Endian.little) / 1e7;
    PmTilesCompression compression(int value) => value < PmTilesCompression.values.length
        ? PmTilesCompression.values[value]
        : PmTilesCompression.unknown;

    return PmTilesHeader(
      rootOffset: u64(8),
      rootLength: u64(16),
      metadataOffset: u64(24),
      metadataLength: u64(32),
      leafOffset: u64(40),
      leafLength: u64(48),
      tileDataOffset: u64(56),
      tileDataLength: u64(64),
      internalCompression: compression(bytes[97]),
      tileCompression: compression(bytes[98]),
      tileType: bytes[99] < PmTilesTileType.values.length
          ? PmTilesTileType.values[bytes[99]]
          : PmTilesTileType.unknown,
      minZoom: bytes[100],
      maxZoom: bytes[101],
      bounds: (e7(102), e7(106), e7(110), e7(114)),
      centerZoom: bytes[118],
      center: (e7(119), e7(123)),
    );
  }
}

/// Little-endian unsigned 64-bit, built from two halves so it also works
/// where integers are JavaScript numbers.
int _uint64(ByteData data, int at) =>
    data.getUint32(at, Endian.little) + data.getUint32(at + 4, Endian.little) * 0x100000000;

/// One index entry: [runLength] tiles in a row starting at [tileId] share the
/// bytes at [offset]. A [runLength] of 0 points to a deeper index instead.
@immutable
class PmTilesEntry {
  const PmTilesEntry(this.tileId, this.offset, this.length, this.runLength);

  final int tileId;
  final int offset;
  final int length;
  final int runLength;
}

/// The number PMTiles gives tile [x], [y] at zoom [z]: every tile of lower
/// zooms first, then a Hilbert curve, so nearby tiles sit near each other in
/// the file.
int pmTilesTileId(int z, int x, int y) {
  if (z < 0 || z > 26) throw RangeError.range(z, 0, 26, 'z');
  final n = 1 << z;
  if (x < 0 || y < 0 || x >= n || y >= n) {
    throw PmTilesException('Tile $z/$x/$y is outside its zoom level');
  }
  var before = 0;
  for (var i = 0; i < z; i++) {
    before += (1 << i) * (1 << i);
  }
  var d = 0;
  var tx = x;
  var ty = y;
  for (var s = n ~/ 2; s > 0; s ~/= 2) {
    final rx = (tx & s) > 0 ? 1 : 0;
    final ry = (ty & s) > 0 ? 1 : 0;
    d += s * s * ((3 * rx) ^ ry);
    // Rotate the quadrant, as the curve does.
    if (ry == 0) {
      if (rx == 1) {
        tx = s - 1 - tx;
        ty = s - 1 - ty;
      }
      final t = tx;
      tx = ty;
      ty = t;
    }
  }
  return before + d;
}

/// Reads an index (a "directory") once it is decompressed.
@visibleForTesting
List<PmTilesEntry> parsePmTilesDirectory(Uint8List bytes) {
  var pos = 0;
  int varint() {
    var value = 0;
    var factor = 1;
    while (true) {
      if (pos >= bytes.length) throw const PmTilesException('Map index is cut short');
      final b = bytes[pos++];
      value += (b & 0x7f) * factor;
      if (b < 0x80) return value;
      factor *= 128;
      if (factor > 0x10000000000000) throw const PmTilesException('Map index is damaged');
    }
  }

  final count = varint();
  final ids = List<int>.filled(count, 0);
  var last = 0;
  for (var i = 0; i < count; i++) {
    last += varint();
    ids[i] = last;
  }
  final runs = [for (var i = 0; i < count; i++) varint()];
  final lengths = [for (var i = 0; i < count; i++) varint()];
  final offsets = List<int>.filled(count, 0);
  for (var i = 0; i < count; i++) {
    final v = varint();
    offsets[i] = v == 0 && i > 0 ? offsets[i - 1] + lengths[i - 1] : v - 1;
  }
  return [
    for (var i = 0; i < count; i++) PmTilesEntry(ids[i], offsets[i], lengths[i], runs[i]),
  ];
}

/// The entry that holds [tileId], or the deeper index that might.
PmTilesEntry? _find(List<PmTilesEntry> entries, int tileId) {
  var lo = 0;
  var hi = entries.length - 1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    final id = entries[mid].tileId;
    if (tileId > id) {
      lo = mid + 1;
    } else if (tileId < id) {
      hi = mid - 1;
    } else {
      return entries[mid];
    }
  }
  if (hi >= 0) {
    final e = entries[hi];
    if (e.runLength == 0 || tileId - e.tileId < e.runLength) return e;
  }
  return null;
}

Uint8List _decompress(Uint8List bytes, PmTilesCompression compression) => switch (compression) {
      PmTilesCompression.none || PmTilesCompression.unknown => bytes,
      PmTilesCompression.gzip => GZipDecoder().decodeBytes(bytes),
      PmTilesCompression.zstd => ZstdDecoder().decodeBytes(bytes),
      PmTilesCompression.brotli =>
        throw const PmTilesException('Brotli-compressed maps are not supported'),
    };

/// An open archive.
class PmTilesArchive {
  PmTilesArchive._(this._source, this.header, this._root);

  final PmTilesSource _source;
  final PmTilesHeader header;
  final List<PmTilesEntry> _root;

  /// Deeper indexes read so far, by offset. A region map has few enough that
  /// keeping the recent ones avoids most re-reads while panning.
  final _leaves = <int, List<PmTilesEntry>>{};
  static const _maxLeaves = 64;

  Map<String, dynamic>? _metadata;

  /// Reads the header and the root index. Throws [PmTilesException] when the
  /// bytes are not a PMTiles v3 archive.
  static Future<PmTilesArchive> open(PmTilesSource source) async {
    final head = await source.read(0, PmTilesHeader.length);
    final header = PmTilesHeader.parse(head);
    final root = parsePmTilesDirectory(_decompress(
      await source.read(header.rootOffset, header.rootLength),
      header.internalCompression,
    ));
    return PmTilesArchive._(source, header, root);
  }

  /// The archive's JSON metadata: layer names, attribution, and so on.
  Future<Map<String, dynamic>> metadata() async {
    if (_metadata != null) return _metadata!;
    if (header.metadataLength == 0) return _metadata = {};
    final raw = _decompress(
      await _source.read(header.metadataOffset, header.metadataLength),
      header.internalCompression,
    );
    final json = jsonDecode(utf8.decode(raw));
    return _metadata = json is Map<String, dynamic> ? json : {};
  }

  /// The tile's bytes, decompressed, or null when the archive has no tile
  /// there (open sea, or outside the region).
  Future<Uint8List?> tile(int z, int x, int y) async {
    if (z < header.minZoom || z > header.maxZoom) return null;
    final id = pmTilesTileId(z, x, y);
    var entries = _root;
    // The spec allows at most three levels below the root.
    for (var depth = 0; depth <= 3; depth++) {
      final entry = _find(entries, id);
      if (entry == null) return null;
      if (entry.runLength > 0) {
        final bytes = await _source.read(header.tileDataOffset + entry.offset, entry.length);
        return _decompress(bytes, header.tileCompression);
      }
      entries = await _leaf(header.leafOffset + entry.offset, entry.length);
    }
    throw const PmTilesException('Map index is too deep');
  }

  Future<List<PmTilesEntry>> _leaf(int offset, int length) async {
    final cached = _leaves.remove(offset);
    if (cached != null) return _leaves[offset] = cached;
    final entries = parsePmTilesDirectory(_decompress(
      await _source.read(offset, length),
      header.internalCompression,
    ));
    if (_leaves.length >= _maxLeaves) _leaves.remove(_leaves.keys.first);
    return _leaves[offset] = entries;
  }

  /// Names of the vector layers inside, from the metadata.
  Future<Set<String>> layerNames() async {
    final layers = (await metadata())['vector_layers'];
    return {
      if (layers is List)
        for (final layer in layers)
          if (layer is Map && layer['id'] is String) layer['id'] as String,
    };
  }

  Future<void> close() => _source.close();
}

/// Hands the map renderer tiles from an offline archive. Where the archive
/// has no tile, the map gets an empty one rather than an error, so open sea
/// and the edges of the region simply show the background.
class PmTilesVectorTileProvider extends VectorTileProvider {
  PmTilesVectorTileProvider(this.archive);

  final PmTilesArchive archive;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    try {
      return await archive.tile(tile.z, tile.x, tile.y) ?? Uint8List(0);
    } catch (e) {
      throw ProviderException(message: '$e', retryable: Retryable.none);
    }
  }

  @override
  int get maximumZoom => archive.header.maxZoom;

  @override
  int get minimumZoom => archive.header.minZoom;

  @override
  TileOffset get tileOffset => TileOffset.DEFAULT;
}
