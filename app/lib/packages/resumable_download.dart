import 'dart:async';
import 'dart:typed_data';

import '../nodes/package_manifest.dart';

/// A byte-range HTTP seam for resumable downloads. Injecting it lets tests drive
/// a deterministic fake (with simulated interruptions) and no real network.
abstract class RangeHttp {
  /// GETs [url] bytes in the inclusive range [[start], [end]]. Implementations
  /// MUST honor the range (send `Range: bytes=start-end`) and apply a timeout.
  /// Throws on a transport failure so the downloader can resume later.
  Future<Uint8List> getRange(Uri url, int start, int end);
}

/// Persists the verified chunks of one pack so a cancelled/failed download
/// leaves what was fetched usable and resumes from where it stopped. On native
/// this is files under path_provider; on web it is IndexedDB/OPFS via the
/// local DB. The abstraction keeps the downloader platform-agnostic and
/// unit-testable with an in-memory store.
abstract class ChunkStore {
  /// Returns the already-stored chunk indices for [packId]/[entryName].
  Future<Set<int>> storedChunks(String packId, String entryName);

  /// Writes one verified chunk.
  Future<void> putChunk(
      String packId, String entryName, int index, Uint8List bytes);

  /// Reads a stored chunk, or null if absent.
  Future<Uint8List?> getChunk(String packId, String entryName, int index);

  /// Deletes every chunk of [packId]/[entryName] (used only AFTER a replacement
  /// verified, never before — the no-premature-delete rule).
  Future<void> deleteEntry(String packId, String entryName);
}

/// A simple in-memory [ChunkStore] for tests and transient use.
class MemoryChunkStore implements ChunkStore {
  final Map<String, Uint8List> _data = {};

  String _key(String p, String e, int i) => '$p\u0000$e\u0000$i';

  @override
  Future<Set<int>> storedChunks(String packId, String entryName) async {
    final prefix = '$packId\u0000$entryName\u0000';
    final out = <int>{};
    for (final k in _data.keys) {
      if (k.startsWith(prefix)) {
        out.add(int.parse(k.substring(prefix.length)));
      }
    }
    return out;
  }

  @override
  Future<void> putChunk(
      String packId, String entryName, int index, Uint8List bytes) async {
    _data[_key(packId, entryName, index)] = bytes;
  }

  @override
  Future<Uint8List?> getChunk(
          String packId, String entryName, int index) async =>
      _data[_key(packId, entryName, index)];

  @override
  Future<void> deleteEntry(String packId, String entryName) async {
    final prefix = '$packId\u0000$entryName\u0000';
    _data.removeWhere((k, _) => k.startsWith(prefix));
  }
}

/// Download progress for one entry: how many of the total chunks are stored.
class DownloadProgress {
  final int storedChunks;
  final int totalChunks;
  const DownloadProgress(this.storedChunks, this.totalChunks);

  /// Fraction in [0,1]. 0 when the size is unknown.
  double get fraction =>
      totalChunks <= 0 ? 0 : storedChunks / totalChunks;

  /// Percent 0..100 (floored) for the `62% of <pack>` label.
  int get percent => (fraction * 100).floor();

  bool get complete => totalChunks > 0 && storedChunks >= totalChunks;
}

/// The outcome of a (possibly resumed) download attempt.
class DownloadResult {
  /// True when every chunk was fetched AND the reassembled SHA-256 matched the
  /// signed-manifest checksum.
  final bool verified;

  /// Progress at the moment the attempt ended (so a partial download shows
  /// `N% of <pack>, resume`).
  final DownloadProgress progress;

  /// A truthful short error, or null on success.
  final String? error;

  const DownloadResult(
      {required this.verified, required this.progress, this.error});
}

/// Resumable, chunked downloader for ONE signed-manifest entry.
///
/// Guarantees (the plan's non-negotiables):
///  * every fetched chunk is persisted immediately, so a cancelled or failed
///    download keeps what it got (partial regions render what exists);
///  * it resumes from the already-stored chunks on a retry;
///  * the download is only reported `verified` when the reassembled bytes'
///    SHA-256 equals the entry's signed checksum (transport is never trusted);
///  * it NEVER deletes anything — merge/replace + retention is the caller's job,
///    and the caller must not delete a prior verified pack until the
///    replacement verifies.
class ResumableDownloader {
  ResumableDownloader({
    required this.http,
    required this.store,
    this.chunkSize = 1 << 16, // 64 KiB
    Future<String> Function(List<int>)? sha256,
  }) : _sha256 = sha256 ?? sha256Hex;

  final RangeHttp http;
  final ChunkStore store;
  final int chunkSize;
  final Future<String> Function(List<int>) _sha256;

  int totalChunksFor(int sizeBytes) =>
      sizeBytes <= 0 ? 0 : ((sizeBytes + chunkSize - 1) ~/ chunkSize);

  /// Current progress for an entry without downloading anything.
  Future<DownloadProgress> progressFor(String packId, ManifestEntry entry) async {
    final total = totalChunksFor(entry.sizeBytes);
    final stored = await store.storedChunks(packId, entry.name);
    // Only count chunks that are in-range (defensive against a changed size).
    final inRange = stored.where((i) => i >= 0 && i < total).length;
    return DownloadProgress(inRange, total);
  }

  /// Downloads (or resumes) [entry] of [packId] from [url], persisting each
  /// chunk as it arrives. [onProgress] is called after every stored chunk so
  /// the UI can live-update the "N%" label. A thrown transport error stops the
  /// attempt but KEEPS the chunks already written (resume later). After all
  /// chunks are present the reassembled SHA-256 is checked against the signed
  /// [entry].sha256; a mismatch returns verified=false WITHOUT deleting the
  /// chunks (the caller decides whether to discard and retry).
  Future<DownloadResult> download(
    String packId,
    ManifestEntry entry,
    Uri url, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    final total = totalChunksFor(entry.sizeBytes);
    if (total <= 0) {
      return const DownloadResult(
          verified: false,
          progress: DownloadProgress(0, 0),
          error: 'unknown size');
    }
    final have = await store.storedChunks(packId, entry.name);
    for (var i = 0; i < total; i++) {
      if (have.contains(i)) continue;
      final start = i * chunkSize;
      final end = ((i + 1) * chunkSize) - 1;
      final lastEnd = entry.sizeBytes - 1;
      final rangeEnd = end < lastEnd ? end : lastEnd;
      try {
        final bytes = await http.getRange(url, start, rangeEnd);
        await store.putChunk(packId, entry.name, i, bytes);
        have.add(i);
        onProgress?.call(DownloadProgress(have.length, total));
      } catch (e) {
        // Keep what we have; report resumable progress.
        return DownloadResult(
          verified: false,
          progress: DownloadProgress(have.length, total),
          error: _short(e),
        );
      }
    }

    // Reassemble and verify against the signed checksum.
    final assembled = BytesBuilder(copy: false);
    for (var i = 0; i < total; i++) {
      final c = await store.getChunk(packId, entry.name, i);
      if (c == null) {
        return DownloadResult(
          verified: false,
          progress: DownloadProgress(total - 1, total),
          error: 'missing chunk after download',
        );
      }
      assembled.add(c);
    }
    final got = await _sha256(assembled.toBytes());
    final verified = got == entry.sha256.toLowerCase();
    return DownloadResult(
      verified: verified,
      progress: DownloadProgress(total, total),
      error: verified ? null : 'checksum mismatch',
    );
  }

  static String _short(Object e) {
    final s = e.toString();
    return s.length > 120 ? '${s.substring(0, 117)}...' : s;
  }
}
