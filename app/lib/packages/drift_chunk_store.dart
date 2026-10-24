import 'package:drift/drift.dart';

import '../db/database.dart';
import 'resumable_download.dart';

/// A [ChunkStore] backed by the local Drift KeyValue table, so verified chunks
/// persist across app restarts on BOTH native and web (Drift uses IndexedDB/
/// OPFS on web). Each chunk is stored as raw bytes under a namespaced key
/// `rpack:<packId>\u0000<entry>\u0000<index>`; the manifest/metadata for a pack
/// live elsewhere (RegionPackStore).
///
/// Web honesty: on web there is no plain filesystem, so a "partial file that
/// survives a reload" means the IndexedDB/OPFS-backed Drift rows — which this
/// store provides. What web CANNOT do is a true OS background download while the
/// tab is closed; that limit is stated in the UI and docs, not faked.
class DriftChunkStore implements ChunkStore {
  DriftChunkStore(this._db);
  final AppDatabase _db;

  static const _prefix = 'rpack:';

  String _key(String p, String e, int i) => '$_prefix$p\u0000$e\u0000$i';
  String _entryPrefix(String p, String e) => '$_prefix$p\u0000$e\u0000';

  @override
  Future<Set<int>> storedChunks(String packId, String entryName) async {
    final pfx = _entryPrefix(packId, entryName);
    final rows = await (_db.select(_db.keyValue)
          ..where((t) => t.key.like('$pfx%')))
        .get();
    final out = <int>{};
    for (final r in rows) {
      final idx = r.key.substring(pfx.length);
      final n = int.tryParse(idx);
      if (n != null) out.add(n);
    }
    return out;
  }

  @override
  Future<void> putChunk(
      String packId, String entryName, int index, Uint8List bytes) async {
    await _db.into(_db.keyValue).insertOnConflictUpdate(
        KeyValueCompanion.insert(key: _key(packId, entryName, index), value: bytes));
  }

  @override
  Future<Uint8List?> getChunk(
      String packId, String entryName, int index) async {
    final row = await (_db.select(_db.keyValue)
          ..where((t) => t.key.equals(_key(packId, entryName, index))))
        .getSingleOrNull();
    return row == null ? null : Uint8List.fromList(row.value);
  }

  @override
  Future<void> deleteEntry(String packId, String entryName) async {
    final pfx = _entryPrefix(packId, entryName);
    await (_db.delete(_db.keyValue)..where((t) => t.key.like('$pfx%'))).go();
  }
}
