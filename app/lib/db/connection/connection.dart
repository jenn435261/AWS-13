// Platform-conditional database connection selector.
//
// Picks the native (FFI SQLite) implementation on Android/iOS/desktop and the
// WASM implementation on web, so the single Flutter codebase compiles for ALL
// targets (including `flutter build web`, which cannot use dart:ffi).
export 'native.dart' if (dart.library.js_interop) 'web.dart';
