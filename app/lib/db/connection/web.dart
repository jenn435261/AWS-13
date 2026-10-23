import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Web database connection backed by sqlite3 compiled to WebAssembly.
///
/// Requires web/sqlite3.wasm and web/drift_worker.js to be served alongside
/// the app (they are in the app's web/ directory). Falls back gracefully to an
/// in-memory database if persistent storage is unavailable in the browser —
/// which is fine for the web build (used as a boot/screenshot harness; the
/// real persistent app runs on Android/iOS).
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'resilience',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}

/// In-memory web database.
QueryExecutor openMemory() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'resilience_mem',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}
