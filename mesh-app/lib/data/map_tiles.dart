import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart'
    show SpriteIndexReader, ThemeReader;

/// The Amazon Location Service API key, set when building:
/// `flutter run --dart-define=AWS_MAP_KEY=...`. The key needs only the
/// `geo-maps:GetTile` action. Without it the map shows pins with no street
/// map. Never commit the key.
const awsMapKey = String.fromEnvironment('AWS_MAP_KEY');

/// The AWS Region the key was made in.
const awsMapRegion =
    String.fromEnvironment('AWS_MAP_REGION', defaultValue: 'us-east-2');

enum MapTilesStatus {
  /// No key in this build.
  notSetUp,
  loading,
  ready,

  /// No internet, or the key was refused.
  unavailable,
}

/// Street map from Amazon Location Service (Maps API v2), drawn under the
/// app's own pins and radio links. The map comes as vector tiles plus a
/// style that says how to draw them, in the app's light or dark look and in
/// its language. With no internet the map shows pins without streets.
class MapTiles extends ChangeNotifier {
  MapTiles({
    this.key = awsMapKey,
    this.region = awsMapRegion,
    http.Client? client,
    this.retryAfter = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final String key;
  final String region;
  final http.Client _client;

  /// How long to wait before trying again after the map became unavailable,
  /// so streets come back on their own when the internet does.
  final Duration retryAfter;

  MapTilesStatus _status = MapTilesStatus.notSetUp;
  Style? _style;
  String? _attribution;
  (bool, String)? _look;
  Timer? _retryTimer;
  bool _disposed = false;

  MapTilesStatus get status => key.isEmpty ? MapTilesStatus.notSetUp : _status;

  /// How to draw the street map, once it is ready.
  Style? get style => status == MapTilesStatus.ready ? _style : null;

  /// The data credit the terms ask for, e.g. "© AWS, HERE".
  String? get attribution => _attribution;

  /// Loads the map style for this look and language, unless it is loaded.
  Future<void> open({required bool dark, required String languageCode}) async {
    if (key.isEmpty) return;
    final look = (dark, languageCode);
    if (look == _look && _status != MapTilesStatus.unavailable) return;
    _look = look;
    _set(MapTilesStatus.loading);
    final query = {'color-scheme': dark ? 'Dark' : 'Light', 'key': key};
    try {
      final response = await _client.get(Uri.https(
        'maps.geo.$region.amazonaws.com',
        '/v2/styles/Standard/descriptor',
        query,
      ));
      if (_disposed || look != _look) return;
      if (response.statusCode != 200) {
        _set(MapTilesStatus.unavailable);
        return;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      tailorStyle(json, languageCode: languageCode);
      final sprites = await _sprites(json['sprite'], query);
      if (_disposed || look != _look) return;

      final providers = <String, VectorTileProvider>{};
      String? attribution;
      for (final MapEntry(key: name, value: source)
          in (json['sources'] as Map<String, dynamic>).entries) {
        final tiles = source['tiles'];
        if (source['type'] != 'vector' || tiles is! List || tiles.isEmpty) continue;
        providers[name] = _ReportingTiles(
          NetworkVectorTileProvider(
            urlTemplate: tiles.first as String,
            maximumZoom: source['maxzoom'] as int? ?? 14,
            minimumZoom: source['minzoom'] as int? ?? 0,
          ),
          onFailed: tileFailed,
        );
        attribution ??= _plainText(source['attribution'] as String?);
      }
      if (providers.isEmpty) {
        _set(MapTilesStatus.unavailable);
        return;
      }
      _style = Style(
        theme: ThemeReader().read(json),
        providers: TileProviders(providers),
        sprites: sprites,
      );
      _attribution = attribution;
      _set(MapTilesStatus.ready);
    } catch (_) {
      if (!_disposed && look == _look) _set(MapTilesStatus.unavailable);
    }
  }

  /// Road shields and place icons. The map still works without them.
  Future<SpriteStyle?> _sprites(Object? sprite, Map<String, String> query) async {
    if (sprite is! String || sprite.isEmpty) return null;
    Uri at(String extension) =>
        Uri.parse('$sprite@2x$extension').replace(queryParameters: query);
    try {
      final response = await _client.get(at('.json'));
      if (response.statusCode != 200) return null;
      return SpriteStyle(
        index: SpriteIndexReader().read(jsonDecode(response.body) as Map<String, dynamic>),
        atlasProvider: () async => (await _client.get(at('.png'))).bodyBytes,
      );
    } catch (_) {
      return null;
    }
  }

  /// A tile failed to load, so the connection is likely gone.
  void tileFailed() {
    if (_status == MapTilesStatus.ready) _set(MapTilesStatus.unavailable);
  }

  void _set(MapTilesStatus status) {
    if (status == MapTilesStatus.unavailable) _scheduleRetry();
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(retryAfter, () {
      final look = _look;
      if (_disposed || look == null || _status != MapTilesStatus.unavailable) return;
      open(dark: look.$1, languageCode: look.$2);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _client.close();
    super.dispose();
  }
}

/// Labels the app leaves off the map, so help and resources stand out:
/// food, nightlife, hotels, shops and businesses. Hospitals, schools,
/// transit and parks stay.
const _hiddenPlaceGroups = ['poi_100_', 'poi_200_', 'poi_500_', 'poi_600_', 'poi_700_'];

/// Name fields to try first for each app language, before the local name.
const _nameFields = {
  'es': ['name:es'],
  'vi': ['name:vi'],
  'zh': ['name:zh-Hans', 'name:zh'],
  'tl': ['name:tl', 'name:fil'],
};

/// Changes the downloaded style in place: hides busy place labels, rewrites
/// rules the map renderer can't read, and shows names in the app's language
/// where the map has them.
@visibleForTesting
void tailorStyle(Map<String, dynamic> style, {required String languageCode}) {
  final layers = style['layers'] as List;
  layers.removeWhere((layer) {
    final id = (layer as Map)['id'] as String? ?? '';
    return _hiddenPlaceGroups.any(id.startsWith);
  });

  for (final layer in layers.cast<Map>()) {
    if (layer.containsKey('filter')) {
      layer['filter'] = _readable(layer['filter'], inFilter: true);
    }
    for (final part in ['layout', 'paint']) {
      final values = layer[part];
      if (values is Map) {
        for (final key in values.keys.toList()) {
          values[key] = _readable(values[key], inFilter: false);
        }
      }
    }
  }

  final fields = _nameFields[languageCode];
  if (fields == null) return;
  Object? translate(Object? value) {
    if (value is List) {
      if (value.isNotEmpty && value.first == 'coalesce') {
        return [
          for (final part in value)
            if (part is List && part.length == 2 && part[0] == 'get' && part[1] == 'name:en')
              ...[for (final f in fields) ['get', f]]
            else
              translate(part),
        ];
      }
      return [for (final part in value) translate(part)];
    }
    return value;
  }

  for (final layer in layers) {
    final layout = (layer as Map)['layout'];
    if (layout is Map && layout.containsKey('text-field')) {
      layout['text-field'] = translate(layout['text-field']);
    }
  }
}

/// The renderer drops any rule it can't read, and a layer with no filter
/// draws everything, which filled the map with cafes and ATMs. So:
/// - `["in", x, ["literal", [...]]]` becomes the `match` it means.
/// - A zoom comparison inside a filter becomes `true`; the layer's own zoom
///   range still applies.
Object? _readable(Object? value, {required bool inFilter}) {
  if (value is! List || value.isEmpty) return value;
  final op = value.first;
  final last = value.last;
  if (op == 'in' && value.length == 3 && last is List && last.length == 2 && last.first == 'literal') {
    return ['match', _readable(value[1], inFilter: inFilter), last[1], true, false];
  }
  if (inFilter &&
      const {'<', '<=', '>', '>=', '==', '!='}.contains(op) &&
      value.any((part) => part is List && part.length == 1 && part.first == 'zoom')) {
    return true;
  }
  return [for (final part in value) _readable(part, inFilter: inFilter)];
}

String? _plainText(String? html) =>
    html?.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Passes tiles through, and reports when the network fails rather than when
/// a tile is simply empty.
class _ReportingTiles extends VectorTileProvider {
  _ReportingTiles(this._inner, {required this.onFailed});

  final VectorTileProvider _inner;
  final VoidCallback onFailed;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    try {
      return await _inner.provide(tile);
    } on ProviderException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 204) onFailed();
      rethrow;
    } catch (_) {
      onFailed();
      rethrow;
    }
  }

  @override
  int get maximumZoom => _inner.maximumZoom;

  @override
  int get minimumZoom => _inner.minimumZoom;

  @override
  TileOffset get tileOffset => _inner.tileOffset;

  @override
  TileProviderType get type => _inner.type;
}
