import 'dart:typed_data';

import 'offline_map_pmtiles.dart';
import 'offline_map_store_memory.dart'
    if (dart.library.io) 'offline_map_store_io.dart' as platform;

/// What the phone remembers about the street map it downloaded.
class OfflineMapInfo {
  const OfflineMapInfo({
    required this.sizeBytes,
    required this.downloadedAt,
    required this.source,
    this.lastModified,
    this.etag,
  });

  final int sizeBytes;
  final DateTime downloadedAt;

  /// Where it came from, so an update asks the same place.
  final String source;

  /// The server's version marks, to tell whether a newer map is waiting.
  final String? lastModified;
  final String? etag;

  Map<String, Object?> toJson() => {
        'sizeBytes': sizeBytes,
        'downloadedAt': downloadedAt.toIso8601String(),
        'source': source,
        'lastModified': lastModified,
        'etag': etag,
      };

  static OfflineMapInfo? fromJson(Object? json) {
    if (json is! Map) return null;
    final size = json['sizeBytes'];
    final at = DateTime.tryParse('${json['downloadedAt']}');
    if (size is! int || at == null) return null;
    return OfflineMapInfo(
      sizeBytes: size,
      downloadedAt: at,
      source: '${json['source'] ?? ''}',
      lastModified: json['lastModified'] as String?,
      etag: json['etag'] as String?,
    );
  }
}

/// A download in progress, kept apart from the map in use until it is
/// complete and checked.
abstract class OfflineMapUpload {
  Future<void> add(List<int> chunk);

  /// The bytes so far, readable, to check them before they replace the map.
  Future<PmTilesSource> open();

  /// Throws the partial download away.
  Future<void> abort();
}

/// Keeps one offline street map on the phone.
abstract class OfflineMapStore {
  /// The saved map's details, or null when there is none.
  Future<OfflineMapInfo?> info();

  /// Opens the saved map for reading.
  Future<PmTilesSource> open();

  Future<OfflineMapUpload> begin();

  /// Makes a finished [upload] the saved map, replacing any older one.
  Future<void> commit(OfflineMapUpload upload, OfflineMapInfo info);

  Future<void> delete();

  /// Files in the app's own storage on a phone; memory on the web preview.
  factory OfflineMapStore.device() => platform.deviceOfflineMapStore();
}

/// Keeps the map in memory: for tests, and for the web preview, which has no
/// files. It is gone when the app closes.
class MemoryOfflineMapStore implements OfflineMapStore {
  Uint8List? _bytes;
  OfflineMapInfo? _info;

  @override
  Future<OfflineMapInfo?> info() async => _bytes == null ? null : _info;

  @override
  Future<PmTilesSource> open() async {
    final bytes = _bytes;
    if (bytes == null) throw const PmTilesException('No offline map saved');
    return MemoryPmTilesSource(bytes);
  }

  @override
  Future<OfflineMapUpload> begin() async => _MemoryUpload();

  @override
  Future<void> commit(OfflineMapUpload upload, OfflineMapInfo info) async {
    _bytes = (upload as _MemoryUpload)._builder.toBytes();
    _info = info;
  }

  @override
  Future<void> delete() async {
    _bytes = null;
    _info = null;
  }
}

class _MemoryUpload implements OfflineMapUpload {
  final _builder = BytesBuilder(copy: false);

  @override
  Future<void> add(List<int> chunk) async => _builder.add(chunk);

  @override
  Future<PmTilesSource> open() async => MemoryPmTilesSource(_builder.toBytes());

  @override
  Future<void> abort() async => _builder.clear();
}
