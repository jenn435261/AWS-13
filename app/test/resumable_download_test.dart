import 'dart:typed_data';

import 'package:resilience/nodes/package_manifest.dart';
import 'package:resilience/packages/resumable_download.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake Range transport over a fixed byte array. It can be told to FAIL after
/// serving N successful ranges, to simulate an interruption; the already-served
/// chunks must survive in the ChunkStore (resume semantics).
class _FakeRangeHttp implements RangeHttp {
  _FakeRangeHttp(this.data, {this.failAfter = -1});
  final Uint8List data;
  int failAfter; // -1 => never fail
  int served = 0;

  @override
  Future<Uint8List> getRange(Uri url, int start, int end) async {
    if (failAfter >= 0 && served >= failAfter) {
      throw Exception('simulated network drop');
    }
    served++;
    final to = (end + 1).clamp(0, data.length);
    return Uint8List.sublistView(data, start, to);
  }
}

Uint8List _makeData(int n) {
  final d = Uint8List(n);
  for (var i = 0; i < n; i++) {
    d[i] = (i * 7 + 3) & 0xff;
  }
  return d;
}

void main() {
  group('ResumableDownloader', () {
    test('interrupted download resumes and final SHA-256 matches', () async {
      final data = _makeData(5000); // with 64 KiB chunks -> 1 chunk; shrink it
      final store = MemoryChunkStore();
      final sha = await sha256Hex(data);
      final entry = ManifestEntry(
          kind: 'map',
          name: 'bay.pmtiles',
          path: '/v1/packages/bay.pmtiles',
          sizeBytes: data.length,
          sha256: sha);

      // Use a small chunk size so there are several chunks to interrupt across.
      final url = Uri.parse('https://cloud/v1/packages/bay.pmtiles');

      // First attempt fails after 3 chunks.
      final failing = _FakeRangeHttp(data, failAfter: 3);
      final d1 = ResumableDownloader(
          http: failing, store: store, chunkSize: 1000);
      final r1 = await d1.download('pack1', entry, url);
      expect(r1.verified, isFalse);
      expect(r1.error, isNotNull);
      expect(r1.progress.storedChunks, 3); // kept the 3 it fetched
      expect(r1.progress.totalChunks, 5);
      expect(r1.progress.percent, 60);

      // Resume with a healthy transport; it must only fetch the remaining 2.
      final healthy = _FakeRangeHttp(data);
      final d2 = ResumableDownloader(
          http: healthy, store: store, chunkSize: 1000);
      final r2 = await d2.download('pack1', entry, url);
      expect(r2.verified, isTrue);
      expect(r2.error, isNull);
      expect(r2.progress.complete, isTrue);
      expect(healthy.served, 2); // resumed, did not refetch the first 3
    });

    test('checksum mismatch returns verified=false and keeps chunks', () async {
      final data = _makeData(3000);
      final store = MemoryChunkStore();
      // Deliberately wrong checksum.
      final entry = ManifestEntry(
          kind: 'map',
          name: 'bad.pmtiles',
          path: '/v1/packages/bad.pmtiles',
          sizeBytes: data.length,
          sha256: 'deadbeef');
      final http = _FakeRangeHttp(data);
      final d = ResumableDownloader(http: http, store: store, chunkSize: 1000);
      final r = await d.download('packbad', entry, Uri.parse('https://c/x'));
      expect(r.verified, isFalse);
      expect(r.error, 'checksum mismatch');
      // Chunks were NOT deleted (no-premature-delete rule).
      final stored = await store.storedChunks('packbad', 'bad.pmtiles');
      expect(stored.length, 3);
    });

    test('a failed replacement does not delete the prior verified pack',
        () async {
      // Prior verified pack is present in the store.
      final good = _makeData(2000);
      final store = MemoryChunkStore();
      final goodSha = await sha256Hex(good);
      final goodEntry = ManifestEntry(
          kind: 'map',
          name: 'downtown.pmtiles',
          path: '/v1/packages/downtown.pmtiles',
          sizeBytes: good.length,
          sha256: goodSha);
      final okHttp = _FakeRangeHttp(good);
      final d = ResumableDownloader(http: okHttp, store: store, chunkSize: 1000);
      final first = await d.download('downtown', goodEntry, Uri.parse('https://c/d'));
      expect(first.verified, isTrue);

      // A replacement download of a DIFFERENT entry fails midway. The caller's
      // contract: do not delete the prior verified pack until the replacement
      // verifies. The downloader never deletes, so the prior pack survives.
      final replacement = _makeData(4000);
      final replEntry = ManifestEntry(
          kind: 'map',
          name: 'downtown-v2.pmtiles',
          path: '/v1/packages/downtown-v2.pmtiles',
          sizeBytes: replacement.length,
          sha256: await sha256Hex(replacement));
      final failing = _FakeRangeHttp(replacement, failAfter: 1);
      final d2 = ResumableDownloader(
          http: failing, store: store, chunkSize: 1000);
      final second = await d2.download('downtown', replEntry, Uri.parse('https://c/d2'));
      expect(second.verified, isFalse);

      // The prior verified pack's chunks are intact.
      final priorProgress = await d.progressFor('downtown', goodEntry);
      expect(priorProgress.complete, isTrue);
    });

    test('progressFor reports partial state for the resume label', () async {
      final data = _makeData(5000);
      final store = MemoryChunkStore();
      final entry = ManifestEntry(
          kind: 'map',
          name: 'p.pmtiles',
          path: '/x',
          sizeBytes: data.length,
          sha256: await sha256Hex(data));
      final http = _FakeRangeHttp(data, failAfter: 2);
      final d = ResumableDownloader(http: http, store: store, chunkSize: 1000);
      await d.download('pk', entry, Uri.parse('https://c/p'));
      final p = await d.progressFor('pk', entry);
      expect(p.storedChunks, 2);
      expect(p.totalChunks, 5);
      expect(p.percent, 40);
      expect(p.complete, isFalse);
    });
  });
}
