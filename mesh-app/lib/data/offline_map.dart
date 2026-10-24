import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' show ThemeReader;

import 'endpoints.dart';
import 'map_tiles.dart';
import 'offline_map_pmtiles.dart';
import 'offline_map_store.dart';
import 'offline_map_theme.dart';

/// Where to download the offline street map instead of the Resilience Node,
/// set when building: `--dart-define=OFFLINE_MAP_URL=https://.../area.pmtiles`.
const offlineMapUrl = String.fromEnvironment('OFFLINE_MAP_URL');

/// The area the Node's map package covers, as the Node names its files.
const offlineMapRegion =
    String.fromEnvironment('OFFLINE_MAP_REGION', defaultValue: 'san-jose');

/// The Node serves `<region>.pmtiles` at `GET /node/v1/map/{region}.pmtiles`,
/// with Range and Last-Modified support (node/internal/packages).
Uri offlineMapSource({String url = offlineMapUrl, String region = offlineMapRegion}) =>
    Uri.parse(url.isNotEmpty ? url : '$nodeBaseUrl/node/v1/map/$region.pmtiles');

/// Why the last download didn't work.
enum OfflineMapProblem {
  /// No answer: not on the Node's Wi-Fi, or no internet for a web address.
  unreachable,

  /// The Node answered but has no map for this area.
  notFound,

  /// The file isn't a vector street map this app can read.
  notAMap,

  /// The phone couldn't save it, for example when it is full.
  storage,
}

/// The street map for when there is no internet: a PMTiles package of
/// OpenStreetMap data downloaded ahead of time, kept on the phone and drawn
/// whenever Amazon Location can't be reached. Amazon's terms don't allow
/// keeping its tiles, so this is a separate map.
class OfflineMap extends ChangeNotifier {
  OfflineMap({
    http.Client? client,
    OfflineMapStore? store,
    Uri? source,
    this.connectTimeout = const Duration(seconds: 20),
  })  : _client = client ?? http.Client(),
        _store = store ?? OfflineMapStore.device(),
        source = source ?? offlineMapSource();

  final http.Client _client;
  final OfflineMapStore _store;

  /// Where downloads and update checks go.
  final Uri source;

  /// How long to wait for the Node to answer, or for the next piece of a
  /// download, before calling it unreachable.
  final Duration connectTimeout;

  Future<void>? _loading;
  OfflineMapInfo? _info;
  PmTilesArchive? _archive;
  OfflineMapSchema _schema = OfflineMapSchema.protomaps;
  String? _attribution;
  final _styles = <(bool, String), Style>{};

  bool _downloading = false;
  bool _cancelled = false;
  int _received = 0;
  int? _total;
  OfflineMapProblem? _problem;
  bool _updateAvailable = false;
  bool _disposed = false;

  /// A map is saved and readable.
  bool get ready => _archive != null;

  /// Details of the saved map, while one is ready.
  OfflineMapInfo? get info => ready ? _info : null;

  bool get downloading => _downloading;

  /// 0 to 1 while downloading, or null when the size isn't known yet.
  double? get progress {
    final total = _total;
    return !_downloading || total == null || total <= 0 ? null : (_received / total).clamp(0, 1);
  }

  int get receivedBytes => _received;
  int? get totalBytes => _total;

  /// Why the last download failed, until the next one starts.
  OfflineMapProblem? get problem => _problem;

  /// The Node has a different map than the saved one.
  bool get updateAvailable => ready && _updateAvailable;

  /// The data credit inside the package, as plain text, when it names
  /// OpenStreetMap. Otherwise the app shows its own OpenStreetMap credit.
  String? get attribution => _attribution;

  /// Reads what is saved. Safe to call more than once.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final info = await _store.info();
      if (info != null) await _openSaved(info);
    } catch (_) {
      // Unreadable or missing storage: behave as if nothing is saved.
    }
    _notify();
  }

  Future<void> _openSaved(OfflineMapInfo info) async {
    final archive = await PmTilesArchive.open(await _store.open());
    final layers = await archive.layerNames();
    final credit = '${(await archive.metadata())['attribution'] ?? ''}'
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    await _archive?.close();
    _archive = archive;
    _info = info;
    _schema = OfflineMapSchema.of(layers);
    _attribution = credit.contains('OpenStreetMap') ? credit : null;
    _styles.clear();
  }

  /// Downloads the map, or a newer one, with progress. The old map stays in
  /// use until the new one has fully arrived and been checked.
  Future<void> download() async {
    if (_downloading) return;
    await load();
    _downloading = true;
    _cancelled = false;
    _received = 0;
    _total = null;
    _problem = null;
    _notify();

    OfflineMapUpload? upload;
    var saving = false;
    try {
      final response = await _client
          .send(http.Request('GET', source))
          .timeout(connectTimeout);
      if (response.statusCode != 200) {
        await response.stream.drain<void>().catchError((_) {});
        _problem = response.statusCode == 404
            ? OfflineMapProblem.notFound
            : OfflineMapProblem.unreachable;
        return;
      }
      _total = response.contentLength;
      upload = await _store.begin();
      var lastShown = 0;
      await for (final chunk in response.stream.timeout(connectTimeout)) {
        if (_cancelled) break;
        saving = true;
        await upload.add(chunk);
        saving = false;
        _received += chunk.length;
        // About a hundred updates per download, not one per packet.
        if (_received - lastShown > (_total ?? 0) / 100 || _received - lastShown > 1 << 20) {
          lastShown = _received;
          _notify();
        }
      }
      if (_cancelled) {
        await upload.abort();
        return;
      }

      if (!await _isStreetMap(upload)) {
        await upload.abort();
        _problem = OfflineMapProblem.notAMap;
        return;
      }
      final info = OfflineMapInfo(
        sizeBytes: _received,
        downloadedAt: DateTime.now(),
        source: source.toString(),
        lastModified: response.headers['last-modified'],
        etag: response.headers['etag'],
      );
      saving = true;
      await _archive?.close();
      _archive = null;
      await _store.commit(upload, info);
      await _openSaved(info);
      _updateAvailable = false;
    } catch (_) {
      await upload?.abort().catchError((_) {});
      _problem = saving ? OfflineMapProblem.storage : OfflineMapProblem.unreachable;
      // A failed save may have closed the map in use; open it again.
      if (_archive == null) await _reopen();
    } finally {
      _downloading = false;
      _notify();
    }
  }

  Future<void> _reopen() async {
    try {
      final info = await _store.info();
      if (info != null) await _openSaved(info);
    } catch (_) {}
  }

  Future<bool> _isStreetMap(OfflineMapUpload upload) async {
    PmTilesSource? source;
    try {
      source = await upload.open();
      final archive = await PmTilesArchive.open(source);
      await archive.metadata();
      return archive.header.tileType == PmTilesTileType.mvt;
    } catch (_) {
      return false;
    } finally {
      await source?.close();
    }
  }

  /// Stops a download; the map in use, if any, stays.
  void cancel() {
    if (_downloading) _cancelled = true;
  }

  /// Asks the Node, without downloading, whether its map differs from the
  /// saved one. Says nothing when the Node can't be reached.
  Future<void> checkForUpdate() async {
    final info = this.info;
    if (info == null || _downloading) return;
    try {
      final r = await _client.head(source).timeout(connectTimeout);
      if (r.statusCode != 200) return;
      final etag = r.headers['etag'];
      final modified = r.headers['last-modified'];
      final size = int.tryParse(r.headers['content-length'] ?? '');
      final differs = etag != null && info.etag != null
          ? etag != info.etag
          : modified != null && info.lastModified != null
              ? modified != info.lastModified
              : size != null && size != info.sizeBytes;
      if (differs != _updateAvailable) {
        _updateAvailable = differs;
        _notify();
      }
    } catch (_) {
      // Offline: nothing to say.
    }
  }

  /// Removes the saved map. The street map then needs internet again.
  Future<void> delete() async {
    cancel();
    await _archive?.close();
    _archive = null;
    _info = null;
    _styles.clear();
    _updateAvailable = false;
    _problem = null;
    try {
      await _store.delete();
    } catch (_) {}
    _notify();
  }

  /// How to draw the saved map in the app's look and language, or null when
  /// none is saved.
  Style? style({required bool dark, required String languageCode}) {
    final archive = _archive;
    if (archive == null) return null;
    return _styles[(dark, languageCode)] ??= Style(
      theme: ThemeReader().read(offlineMapStyle(
        schema: _schema,
        dark: dark,
        languageCode: languageCode,
      )),
      providers: TileProviders({offlineMapSourceId: PmTilesVectorTileProvider(archive)}),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelled = true;
    _archive?.close();
    _client.close();
    super.dispose();
  }
}

OfflineMap? _shared;

/// The phone's one offline street map, shared by the map and Offline
/// downloads.
OfflineMap get offlineMap => _shared ??= OfflineMap()..load();

/// Lets a test use its own offline map; null goes back to the default.
@visibleForTesting
set debugOfflineMap(OfflineMap? map) => _shared = map;

/// Which street map is under the pins.
enum StreetMap {
  /// Amazon Location, over the internet.
  online,

  /// The downloaded OpenStreetMap package.
  offline,

  /// Neither: pins, radios and requests on a plain background.
  none,
}

/// Amazon's map while it works; otherwise the downloaded one, if any.
(StreetMap, Style?) pickStreetMap(
  MapTiles online,
  OfflineMap offline, {
  required bool dark,
  required String languageCode,
}) {
  final style = online.style;
  if (style != null) return (StreetMap.online, style);
  final fallback = offline.style(dark: dark, languageCode: languageCode);
  return fallback == null ? (StreetMap.none, null) : (StreetMap.offline, fallback);
}
