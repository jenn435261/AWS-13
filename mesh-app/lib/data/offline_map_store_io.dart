import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'offline_map_pmtiles.dart';
import 'offline_map_store.dart';

OfflineMapStore deviceOfflineMapStore() => FileOfflineMapStore();

/// Keeps the map as a file in the app's own support folder, which the phone
/// does not clear to free space (unlike a cache folder).
class FileOfflineMapStore implements OfflineMapStore {
  FileOfflineMapStore({Future<Directory> Function()? directory})
      : _directory = directory ?? _appDirectory;

  final Future<Directory> Function() _directory;

  static Future<Directory> _appDirectory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/offline_map');

  Future<File> _file(String name) async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return File('${dir.path}/$name');
  }

  Future<File> get _map => _file('street_map.pmtiles');
  Future<File> get _meta => _file('street_map.json');

  @override
  Future<OfflineMapInfo?> info() async {
    final meta = await _meta;
    if (!await meta.exists() || !await (await _map).exists()) return null;
    try {
      return OfflineMapInfo.fromJson(jsonDecode(await meta.readAsString()));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<PmTilesSource> open() async => FilePmTilesSource(await (await _map).open());

  @override
  Future<OfflineMapUpload> begin() async {
    final part = await _file('street_map.pmtiles.part');
    return _FileUpload(part, await part.open(mode: FileMode.write));
  }

  @override
  Future<void> commit(OfflineMapUpload upload, OfflineMapInfo info) async {
    final part = upload as _FileUpload;
    await part.finish();
    await part.file.rename((await _map).path);
    await (await _meta).writeAsString(jsonEncode(info.toJson()), flush: true);
  }

  @override
  Future<void> delete() async {
    for (final file in [await _meta, await _map]) {
      if (await file.exists()) await file.delete();
    }
  }
}

class _FileUpload implements OfflineMapUpload {
  _FileUpload(this.file, this._sink);

  final File file;
  final RandomAccessFile _sink;
  bool _closed = false;

  @override
  Future<void> add(List<int> chunk) => _sink.writeFrom(chunk);

  Future<void> finish() async {
    if (_closed) return;
    _closed = true;
    await _sink.flush();
    await _sink.close();
  }

  @override
  Future<PmTilesSource> open() async {
    await _sink.flush();
    return FilePmTilesSource(await file.open());
  }

  @override
  Future<void> abort() async {
    await finish();
    if (await file.exists()) await file.delete();
  }
}

/// Reads parts of a file. A file handle does one thing at a time, so reads
/// wait their turn.
class FilePmTilesSource implements PmTilesSource {
  FilePmTilesSource(this._file);

  final RandomAccessFile _file;
  Future<void> _turn = Future.value();

  @override
  Future<Uint8List> read(int offset, int length) {
    final result = _turn.then((_) async {
      await _file.setPosition(offset);
      final bytes = await _file.read(length);
      if (bytes.length != length) {
        throw const PmTilesException('Read past the end of the map file');
      }
      return bytes;
    });
    _turn = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<void> close() => _turn.then((_) => _file.close());
}
