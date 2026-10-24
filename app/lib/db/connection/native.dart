import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Native (Android/iOS/desktop) database connection backed by the bundled
/// SQLite via FFI. Used on every non-web platform.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dir.path, 'resilience.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// In-memory native database (used by tests).
QueryExecutor openMemory() => NativeDatabase.memory();
