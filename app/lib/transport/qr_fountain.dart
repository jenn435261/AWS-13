import 'dart:convert';
import 'dart:typed_data';

/// Loss-tolerant, order-independent chunking codec for animated QR transfer
/// (spec §6.1).
///
/// ## Why not a plain "chunk N of M" scheme?
///
/// A camera scanning an animated QR code drops frames: it misses whatever is on
/// screen while it is busy decoding the previous frame, and it re-reads frames
/// it has already seen. A naive "chunk i of n" stream therefore forces the
/// sender to loop forever and the receiver to wait for *every* distinct index
/// to come around — a single persistently-missed index stalls the whole
/// transfer.
///
/// We instead use a **Luby-Transform (LT) fountain code**. The sender emits an
/// endless stream of *coded* frames, each the XOR of a pseudo-random subset of
/// the K source blocks (the subset is derived deterministically from the
/// frame's seed, so the receiver can reconstruct the same subset). As soon as
/// the receiver has collected *slightly more than K* usable frames — in any
/// order, with arbitrary losses and duplicates — belief-propagation peeling
/// recovers all K source blocks. There is no "missing index 7 forever" failure
/// mode: any fresh frame with a new seed helps.
///
/// Integrity is layered on top and is non-negotiable:
///   * every frame carries a CRC-32 so a corrupt scan is dropped, not peeled;
///   * the header carries a SHA-256 of the *entire* original payload, checked
///     after reassembly before the bytes are handed to the caller. A mangled or
///     maliciously-substituted payload fails this check and is rejected.
///
/// The decoded payload is still just bytes — for QR event transfer those bytes
/// are a protobuf `EventBatch` whose individual events are each verified by
/// `EventStore.apply` (Ed25519 + content hash) before anything is stored. The
/// fountain layer makes delivery robust; it never grants trust.
///
/// ## Realistic throughput
///
/// A QR version ~15 at ECC level M holds roughly 500 usable bytes; at 10 fps
/// with ~460-byte block bodies that is a few KB/s of goodput once fountain
/// overhead (~5-10%) is accounted for. This comfortably moves identity cards,
/// contact bundles, and small signed-event batches in a few seconds; it is NOT
/// for map packs or media — those stay on the chunked HTTP / nearby paths.
import '../core/hashing.dart' as hashing;

/// Container magic: ASCII 'Q','F' (QR Fountain).
const int _magic0 = 0x51;
const int _magic1 = 0x46;

/// Wire version of the frame container.
const int _version = 1;

/// Default source-block body size in bytes. Chosen so one coded frame
/// (header + body, base64url-expanded) fits a mid-density QR comfortably.
const int kDefaultBlockSize = 400;

/// A single coded frame produced by [QrFountainEncoder].
///
/// Wire layout (big-endian), before base64url for display in a QR:
/// ```
/// magic0 magic1 version          (3 bytes)
/// totalLen        uint32         (length of the original payload)
/// blockSize       uint16         (source block body size)
/// numBlocks       uint16         (K = ceil(totalLen / blockSize))
/// sha256          32 bytes       (digest of the whole original payload)
/// seed            uint32         (PRNG seed selecting the source subset)
/// bodyLen         uint16         (length of the coded body that follows)
/// body            bodyLen bytes  (XOR of the selected source blocks)
/// crc32           uint32         (CRC-32 over everything above)
/// ```
class QrFrame {
  const QrFrame({
    required this.totalLen,
    required this.blockSize,
    required this.numBlocks,
    required this.sha256,
    required this.seed,
    required this.body,
  });

  final int totalLen;
  final int blockSize;
  final int numBlocks;
  final Uint8List sha256;
  final int seed;
  final Uint8List body;

  /// Encodes this frame to its raw byte form (pre-base64).
  Uint8List toBytes() {
    final bb = BytesBuilder();
    final head = Uint8List(3 + 4 + 2 + 2 + 32 + 4 + 2);
    final bd = ByteData.view(head.buffer);
    head[0] = _magic0;
    head[1] = _magic1;
    head[2] = _version;
    bd.setUint32(3, totalLen, Endian.big);
    bd.setUint16(7, blockSize, Endian.big);
    bd.setUint16(9, numBlocks, Endian.big);
    head.setRange(11, 43, sha256);
    bd.setUint32(43, seed, Endian.big);
    bd.setUint16(47, body.length, Endian.big);
    bb.add(head);
    bb.add(body);
    final withoutCrc = bb.toBytes();
    final crc = _crc32(withoutCrc);
    final crcBytes = Uint8List(4);
    ByteData.view(crcBytes.buffer).setUint32(0, crc, Endian.big);
    final out = BytesBuilder()
      ..add(withoutCrc)
      ..add(crcBytes);
    return out.toBytes();
  }

  /// Encodes this frame as a QR-friendly base64url string (no padding).
  String toQrString() => base64Url.encode(toBytes()).replaceAll('=', '');

  /// Parses a raw frame, returning null if it is malformed or its CRC fails.
  static QrFrame? tryParse(Uint8List data) {
    if (data.length < 3 + 4 + 2 + 2 + 32 + 4 + 2 + 4) return null;
    if (data[0] != _magic0 || data[1] != _magic1 || data[2] != _version) {
      return null;
    }
    final bd = ByteData.view(data.buffer, data.offsetInBytes, data.length);
    final totalLen = bd.getUint32(3, Endian.big);
    final blockSize = bd.getUint16(7, Endian.big);
    final numBlocks = bd.getUint16(9, Endian.big);
    final sha = Uint8List.fromList(data.sublist(11, 43));
    final seed = bd.getUint32(43, Endian.big);
    final bodyLen = bd.getUint16(47, Endian.big);
    final headEnd = 49;
    if (data.length != headEnd + bodyLen + 4) return null;
    final body = Uint8List.fromList(data.sublist(headEnd, headEnd + bodyLen));
    final storedCrc = bd.getUint32(headEnd + bodyLen, Endian.big);
    final computed = _crc32(Uint8List.view(
        data.buffer, data.offsetInBytes, headEnd + bodyLen));
    if (storedCrc != computed) return null;
    if (blockSize == 0 || numBlocks == 0) return null;
    return QrFrame(
      totalLen: totalLen,
      blockSize: blockSize,
      numBlocks: numBlocks,
      sha256: sha,
      seed: seed,
      body: body,
    );
  }

  /// Parses a base64url QR string, returning null on any decode/CRC failure.
  static QrFrame? tryParseQrString(String s) {
    if (s.isEmpty) return null;
    var padded = s;
    final rem = padded.length % 4;
    if (rem != 0) padded += '=' * (4 - rem);
    Uint8List bytes;
    try {
      bytes = base64Url.decode(padded);
    } catch (_) {
      return null;
    }
    return tryParse(bytes);
  }
}

/// Deterministic PRNG (SplitMix32) so sender and receiver derive the same
/// source-block subset from a frame seed without transmitting the index set.
class _SplitMix32 {
  _SplitMix32(this._state);
  int _state;

  int next() {
    _state = (_state + 0x9e3779b9) & 0xffffffff;
    int z = _state;
    z = (z ^ (z >> 16)) & 0xffffffff;
    z = (z * 0x85ebca6b) & 0xffffffff;
    z = (z ^ (z >> 13)) & 0xffffffff;
    z = (z * 0xc2b2ae35) & 0xffffffff;
    z = (z ^ (z >> 16)) & 0xffffffff;
    return z;
  }

  int nextInt(int bound) => next() % bound;
}

/// The degree distribution + source-index selection shared by encoder and
/// decoder, keyed only by [seed] and [numBlocks]. Robust-Soliton-ish but kept
/// simple and fully deterministic.
List<int> selectBlocks(int seed, int numBlocks) {
  final rng = _SplitMix32(seed & 0xffffffff);
  // The first [numBlocks] seeds are "systematic": seed i (0<=i<K) codes exactly
  // source block i. This guarantees that a clean, loss-free scan degrades to a
  // plain chunked transfer and always terminates, while higher seeds add the
  // fountain redundancy that tolerates loss.
  if (seed < numBlocks) {
    return <int>[seed];
  }
  // Degree: mostly small, occasionally large (helps peeling).
  int degree;
  final r = rng.nextInt(100);
  if (r < 50) {
    degree = 1;
  } else if (r < 85) {
    degree = 2;
  } else if (r < 95) {
    degree = 3;
  } else {
    degree = 4 + rng.nextInt(numBlocks > 8 ? 4 : 1);
  }
  if (degree > numBlocks) degree = numBlocks;
  final chosen = <int>{};
  while (chosen.length < degree) {
    chosen.add(rng.nextInt(numBlocks));
  }
  return chosen.toList()..sort();
}

/// Produces an endless stream of coded [QrFrame]s for a fixed payload.
class QrFountainEncoder {
  QrFountainEncoder(Uint8List payload, {int blockSize = kDefaultBlockSize})
      : assert(payload.isNotEmpty, 'payload must not be empty'),
        assert(blockSize > 0 && blockSize <= 0xffff),
        _payload = payload,
        _blockSize = blockSize,
        _numBlocks = ((payload.length + blockSize - 1) ~/ blockSize),
        _sha = hashing.sha256(payload) {
    // Build padded source blocks (last block zero-padded to blockSize).
    _blocks = List<Uint8List>.generate(_numBlocks, (i) {
      final start = i * _blockSize;
      final end = (start + _blockSize <= _payload.length)
          ? start + _blockSize
          : _payload.length;
      final b = Uint8List(_blockSize);
      b.setRange(0, end - start, _payload.sublist(start, end));
      return b;
    });
  }

  final Uint8List _payload;
  final int _blockSize;
  final int _numBlocks;
  final Uint8List _sha;
  late final List<Uint8List> _blocks;

  int _seed = 0;

  int get numBlocks => _numBlocks;
  int get totalLen => _payload.length;
  Uint8List get sha256 => _sha;

  /// Builds the frame for an explicit [seed] (useful in tests).
  QrFrame frameForSeed(int seed) {
    final indices = selectBlocks(seed, _numBlocks);
    final body = Uint8List(_blockSize);
    for (final idx in indices) {
      final src = _blocks[idx];
      for (int j = 0; j < _blockSize; j++) {
        body[j] ^= src[j];
      }
    }
    return QrFrame(
      totalLen: _payload.length,
      blockSize: _blockSize,
      numBlocks: _numBlocks,
      sha256: _sha,
      seed: seed,
      body: body,
    );
  }

  /// Returns the next coded frame and advances the internal seed counter.
  QrFrame next() {
    final f = frameForSeed(_seed);
    _seed = (_seed + 1) & 0xffffffff;
    return f;
  }
}

/// Collects coded frames and peels them into the original payload.
class QrFountainDecoder {
  QrFountainDecoder();

  int? _totalLen;
  int? _blockSize;
  int? _numBlocks;
  Uint8List? _sha;

  // Pending coded symbols still to be peeled: index-set -> body.
  final List<_Symbol> _symbols = <_Symbol>[];
  // Recovered source blocks.
  late List<Uint8List?> _recovered;
  int _recoveredCount = 0;
  final Set<int> _seenSeeds = <int>{};

  Uint8List? _result;

  /// Number of source blocks recovered so far.
  int get recovered => _recoveredCount;

  /// Total number of source blocks (null until the first valid frame).
  int? get numBlocks => _numBlocks;

  /// True once the payload is fully recovered and its SHA-256 verified.
  bool get isComplete => _result != null;

  /// The verified payload, or null until [isComplete].
  Uint8List? get result => _result;

  /// A progress string like "212/340 frames" (really blocks) for the UI.
  String progress() => '$_recoveredCount/${_numBlocks ?? '?'}';

  /// Feeds one scanned [QrFrame]. Returns true if this frame advanced recovery.
  ///
  /// Duplicate seeds and corrupt frames (already CRC-rejected at parse) are
  /// ignored. If the header does not match a previously-seen header (different
  /// payload), the frame is ignored.
  bool addFrame(QrFrame f) {
    if (_result != null) return false;
    if (_numBlocks == null) {
      _totalLen = f.totalLen;
      _blockSize = f.blockSize;
      _numBlocks = f.numBlocks;
      _sha = f.sha256;
      _recovered = List<Uint8List?>.filled(f.numBlocks, null);
    } else {
      // Reject frames that belong to a different payload/session.
      if (f.totalLen != _totalLen ||
          f.blockSize != _blockSize ||
          f.numBlocks != _numBlocks ||
          !_bytesEqual(f.sha256, _sha!)) {
        return false;
      }
    }
    if (!_seenSeeds.add(f.seed)) return false;
    if (f.body.length != _blockSize) return false;

    final indices = selectBlocks(f.seed, _numBlocks!);
    _symbols.add(_Symbol(indices.toSet(), Uint8List.fromList(f.body)));
    final advanced = _peel();
    if (_recoveredCount == _numBlocks && _result == null) {
      _finish();
    }
    return advanced;
  }

  /// Convenience: parse + add a raw QR string. Returns true if it advanced.
  bool addQrString(String s) {
    final f = QrFrame.tryParseQrString(s);
    if (f == null) return false;
    return addFrame(f);
  }

  // Belief-propagation peeling: repeatedly resolve degree-1 symbols and
  // substitute recovered blocks out of higher-degree symbols.
  bool _peel() {
    bool advancedOverall = false;
    bool progress = true;
    while (progress) {
      progress = false;
      for (final sym in _symbols) {
        // Remove already-recovered indices from this symbol.
        final toRemove = <int>[];
        for (final idx in sym.indices) {
          if (_recovered[idx] != null) toRemove.add(idx);
        }
        for (final idx in toRemove) {
          _xorInto(sym.body, _recovered[idx]!);
          sym.indices.remove(idx);
        }
        if (sym.indices.length == 1) {
          final idx = sym.indices.first;
          if (_recovered[idx] == null) {
            _recovered[idx] = Uint8List.fromList(sym.body);
            _recoveredCount++;
            sym.indices.clear();
            progress = true;
            advancedOverall = true;
          }
        }
      }
      // Drop resolved/empty symbols.
      _symbols.removeWhere((s) => s.indices.isEmpty);
    }
    return advancedOverall;
  }

  void _finish() {
    final out = Uint8List(_totalLen!);
    int written = 0;
    for (int i = 0; i < _numBlocks!; i++) {
      final block = _recovered[i]!;
      final take = (written + _blockSize! <= _totalLen!)
          ? _blockSize!
          : _totalLen! - written;
      out.setRange(written, written + take, block.sublist(0, take));
      written += take;
    }
    // Final integrity gate: the whole-payload SHA-256 must match the header.
    final digest = hashing.sha256(out);
    if (!_bytesEqual(digest, _sha!)) {
      // Corruption/substitution: keep collecting (do not surface bad bytes).
      return;
    }
    _result = out;
  }

  static void _xorInto(Uint8List dst, Uint8List src) {
    final n = dst.length < src.length ? dst.length : src.length;
    for (int i = 0; i < n; i++) {
      dst[i] ^= src[i];
    }
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _Symbol {
  _Symbol(this.indices, this.body);
  final Set<int> indices;
  final Uint8List body;
}

// --- CRC-32 (IEEE 802.3) ----------------------------------------------------

final List<int> _crcTable = _buildCrcTable();

List<int> _buildCrcTable() {
  final table = List<int>.filled(256, 0);
  for (int n = 0; n < 256; n++) {
    int c = n;
    for (int k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xedb88320 ^ (c >> 1)) : (c >> 1);
    }
    table[n] = c & 0xffffffff;
  }
  return table;
}

int _crc32(Uint8List data) {
  int crc = 0xffffffff;
  for (final b in data) {
    crc = _crcTable[(crc ^ b) & 0xff] ^ (crc >> 8);
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
