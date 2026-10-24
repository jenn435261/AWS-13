import '../db/json_store.dart';
import 'position_service.dart';

/// Persists the single last-good device fix in the local KeyValue table under
/// `loc:lastfix`, so the map can centre on it and new posts can default to it
/// (labelled "last known, `<age>`") while a fresh GPS fix is still pending.
///
/// Privacy: the full-precision pair lives ONLY in this local row; it is rounded
/// to ~110 m by [geoPointFor] before any event is built, and no coordinate is
/// ever written to a log line.
class LastFixStore {
  LastFixStore(JsonStore store) : _store = store;

  final JsonStore _store;

  static const String _id = 'lastfix';

  /// Reads the cached fix, or null when none has been stored yet (or the row
  /// is corrupt).
  Future<LastFix?> read() async {
    final all = await _store.all();
    for (final row in all) {
      final fix = LastFix.fromJson(row);
      if (fix != null) return fix;
    }
    return null;
  }

  /// Stores [fix] as the new last-good fix (overwriting any previous one).
  Future<void> write(LastFix fix) => _store.put(_id, fix.toJson());

  /// Clears the cached fix.
  Future<void> clear() => _store.delete(_id);
}
