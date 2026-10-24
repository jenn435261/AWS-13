import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mesh_app/data/map_tiles.dart';

/// A small style in the shape Amazon Location sends, parsed as real JSON is.
Map<String, dynamic> _style() => jsonDecode(jsonEncode({
      'version': 8,
      'sources': {
        'aws': {
          'type': 'vector',
          'tiles': ['https://maps.geo.us-east-2.amazonaws.com/v2/tiles/vector.basemap/{z}/{x}/{y}?key=k1'],
          'maxzoom': 17,
          'attribution': "© <a href='https://aws.amazon.com'>AWS</a>, HERE",
        },
      },
      'sprite': 'https://maps.geo.us-east-2.amazonaws.com/v2/styles/Standard/sprites/sprites',
      'layers': [
        {'id': 'background', 'type': 'background', 'paint': {'background-color': '#ffffff'}},
        for (final id in ['poi_600_shopping', 'poi_100_food_drink', 'poi_800_facilities'])
          {
            'id': id,
            'type': 'symbol',
            'source': 'aws',
            'source-layer': 'pois',
            'layout': {
              'text-field': [
                'coalesce',
                ['get', 'name:en'],
                ['get', 'name'],
              ],
            },
          },
      ],
    })) as Map<String, dynamic>;

bool _isStyle(http.Request r) => r.url.path.endsWith('/descriptor');

void main() {
  test('without a key the map says it is not set up and asks nothing', () async {
    var calls = 0;
    final tiles = MapTiles(key: '', client: MockClient((_) async {
      calls++;
      return http.Response('', 500);
    }));
    await tiles.open(dark: false, languageCode: 'en');
    expect(tiles.status, MapTilesStatus.notSetUp);
    expect(tiles.style, isNull);
    expect(calls, 0);
    tiles.dispose();
  });

  test('asks Amazon Location for the right look, then shows its data credit', () async {
    late Uri asked;
    final tiles = MapTiles(key: 'k1', client: MockClient((request) async {
      if (!_isStyle(request)) return http.Response('', 404);
      asked = request.url;
      return http.Response(jsonEncode(_style()), 200);
    }));
    await tiles.open(dark: true, languageCode: 'en');

    expect(asked.host, 'maps.geo.us-east-2.amazonaws.com');
    expect(asked.path, '/v2/styles/Standard/descriptor');
    expect(asked.queryParameters, {'color-scheme': 'Dark', 'key': 'k1'});
    expect(tiles.status, MapTilesStatus.ready);
    expect(tiles.style, isNotNull);
    expect(tiles.attribution, '© AWS, HERE');
    tiles.dispose();
  });

  test('a refused key or no internet shows the map as unavailable', () async {
    final refused = MapTiles(key: 'bad', client: MockClient((_) async => http.Response('', 403)));
    await refused.open(dark: false, languageCode: 'en');
    expect(refused.status, MapTilesStatus.unavailable);
    refused.dispose();

    final offline = MapTiles(key: 'k1', client: MockClient((_) async => throw http.ClientException('offline')));
    await offline.open(dark: false, languageCode: 'en');
    expect(offline.status, MapTilesStatus.unavailable);
    offline.dispose();
  });

  test('after a failed tile, the map retries on its own', () async {
    var styleCalls = 0;
    final tiles = MapTiles(
      key: 'k1',
      retryAfter: const Duration(milliseconds: 10),
      client: MockClient((request) async {
        if (!_isStyle(request)) return http.Response('', 404);
        styleCalls++;
        return http.Response(jsonEncode(_style()), 200);
      }),
    );
    addTearDown(tiles.dispose);
    await tiles.open(dark: false, languageCode: 'en');
    tiles.tileFailed();
    expect(tiles.status, MapTilesStatus.unavailable);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect((tiles.status, styleCalls), (MapTilesStatus.ready, 2));
  });

  test('a late answer for the old look is ignored', () async {
    final first = Completer<http.Response>();
    final looks = <String>[];
    final tiles = MapTiles(
      key: 'k1',
      client: MockClient((request) {
        if (!_isStyle(request)) return Future.value(http.Response('', 404));
        looks.add(request.url.queryParameters['color-scheme']!);
        return looks.length == 1
            ? first.future
            : Future.value(http.Response(jsonEncode(_style()), 200));
      }),
    );
    addTearDown(tiles.dispose);
    final light = tiles.open(dark: false, languageCode: 'en');
    await tiles.open(dark: true, languageCode: 'en');
    final darkStyle = tiles.style;
    first.complete(http.Response(jsonEncode(_style()), 200));
    await light;
    expect(looks, ['Light', 'Dark']);
    expect(tiles.style, same(darkStyle));
  });

  group('the style is tailored', () {
    List<String> ids(Map<String, dynamic> style) =>
        [for (final l in style['layers'] as List) (l as Map)['id'] as String];
    Object? nameField(Map<String, dynamic> style) =>
        ((style['layers'] as List).last as Map)['layout']['text-field'];

    test('shops and restaurants are hidden; hospitals and schools stay', () {
      final style = _style();
      tailorStyle(style, languageCode: 'en');
      expect(ids(style), ['background', 'poi_800_facilities']);
    });

    test('rules the renderer cannot read are rewritten, so no layer shows everything', () {
      final style = _style();
      final transit = {
        'id': 'poi_400_transit',
        'type': 'symbol',
        'source': 'aws',
        'source-layer': 'pois',
        'filter': [
          'all',
          ['in', ['get', 'pds_category'], ['literal', ['400-1', '400-2']]],
          ['>=', ['zoom'], ['to-number', ['get', 'min_zoom']]],
        ],
      };
      (style['layers'] as List).add(transit);
      tailorStyle(style, languageCode: 'en');
      expect(transit['filter'], [
        'all',
        ['match', ['get', 'pds_category'], ['400-1', '400-2'], true, false],
        true,
      ]);
    });

    test('names show in the app language, falling back to the local name', () {
      final es = _style();
      tailorStyle(es, languageCode: 'es');
      expect(nameField(es), ['coalesce', ['get', 'name:es'], ['get', 'name']]);

      final zh = _style();
      tailorStyle(zh, languageCode: 'zh');
      expect(nameField(zh), [
        'coalesce',
        ['get', 'name:zh-Hans'],
        ['get', 'name:zh'],
        ['get', 'name'],
      ]);

      final en = _style();
      tailorStyle(en, languageCode: 'en');
      expect(nameField(en), ['coalesce', ['get', 'name:en'], ['get', 'name']]);
    });
  });
}
