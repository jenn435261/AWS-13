import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Web: the `record` plugin returns a blob: URL for the recording; fetch its
/// bytes over HTTP (same-origin blob URLs resolve locally in the browser).
Future<Uint8List?> readRecordedBytes(String path) async {
  try {
    final r = await http.get(Uri.parse(path));
    if (r.statusCode == 200) return r.bodyBytes;
    return null;
  } catch (_) {
    return null;
  }
}
