import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

/// Small JSON records in the existing KeyValue table, namespaced by a prefix
/// ("node:", "pkg:", ...). Used for user-managed lists that are local-only
/// (saved nodes, saved packages, settings) and need create/read/update/delete.
class JsonStore {
  JsonStore(this._db, this.prefix);

  final AppDatabase _db;
  final String prefix;

  Future<List<Map<String, dynamic>>> all() async {
    final rows = await (_db.select(_db.keyValue)
          ..where((t) => t.key.like('$prefix%')))
        .get();
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      try {
        out.add(jsonDecode(utf8.decode(r.value)) as Map<String, dynamic>);
      } catch (_) {
        // A corrupt row must never break the screen that lists these.
      }
    }
    return out;
  }

  Future<void> put(String id, Map<String, dynamic> value) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(value)));
    await _db.into(_db.keyValue).insertOnConflictUpdate(
        KeyValueCompanion.insert(key: '$prefix$id', value: bytes));
  }

  Future<void> delete(String id) => (_db.delete(_db.keyValue)
        ..where((t) => t.key.equals('$prefix$id')))
      .go();
}
