/// Platform-conditional reader for the bytes captured by the `record` plugin.
///
/// Native reads a file path with dart:io; web fetches the returned blob URL.
library;

export 'recorded_bytes_io.dart' if (dart.library.js_interop) 'recorded_bytes_web.dart';
