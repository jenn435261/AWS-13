import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mesh_app/data/map_tiles.dart';

void main() {
  test('without a key the map says it is not set up and asks nothing', () async {
    var calls = 0;
    final tiles = MapTiles(key: '', client: MockClient((_) async {
      calls++;
      return http.Response('', 500);
    }));
    await tiles.open(dark: false, languageCode: 'en');
    expect(tiles.status, MapTilesStatus.notSetUp);
    expect(tiles.urlTemplate, isNull);
    expect(calls, 0);
    tiles.dispose();
  });

  test('a session gives tile addresses in the right look and language', () async {
    late Map<String, dynamic> sent;
    final tiles = MapTiles(key: 'k1', client: MockClient((request) async {
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      expect(request.url.path, '/v1/createSession');
      return http.Response(jsonEncode({'session': 's9'}), 200);
    }));
    await tiles.open(dark: true, languageCode: 'zh');

    expect(tiles.status, MapTilesStatus.ready);
    expect(tiles.urlTemplate, contains('session=s9'));
    expect(tiles.urlTemplate, contains('key=k1'));
    expect(sent['language'], 'zh-CN');
    expect(sent['mapType'], 'roadmap');
    expect(jsonEncode(sent['styles']), contains('#111a2c'));
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

  test('a failing tile marks the map unavailable; reopening retries', () async {
    var calls = 0;
    final tiles = MapTiles(key: 'k1', client: MockClient((_) async {
      calls++;
      return http.Response(jsonEncode({'session': 's$calls'}), 200);
    }));
    await tiles.open(dark: false, languageCode: 'en');
    tiles.tileFailed();
    expect(tiles.status, MapTilesStatus.unavailable);
    await tiles.open(dark: false, languageCode: 'en');
    expect((tiles.status, calls), (MapTilesStatus.ready, 2));
    tiles.dispose();
  });

  test('if Google refuses the extra options, the standard map is used', () async {
    final bodies = <Map<String, dynamic>>[];
    final tiles = MapTiles(key: 'k1', client: MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      bodies.add(body);
      return body.containsKey('styles')
          ? http.Response('{"error": "bad field"}', 400)
          : http.Response(jsonEncode({'session': 'plain'}), 200);
    }));
    await tiles.open(dark: false, languageCode: 'es');
    expect(tiles.status, MapTilesStatus.ready);
    expect(bodies, hasLength(2));
    expect(bodies.last.keys, unorderedEquals(['mapType', 'language', 'region']));
    tiles.dispose();
  });
}
