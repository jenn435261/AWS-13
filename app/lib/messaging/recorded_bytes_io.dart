import 'dart:io';
import 'dart:typed_data';

/// Native: the `record` plugin writes the recording to a file path.
Future<Uint8List?> readRecordedBytes(String path) async {
  try {
    final f = File(path);
    if (!await f.exists()) return null;
    return Uint8List.fromList(await f.readAsBytes());
  } catch (_) {
    return null;
  }
}
