import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mesh_app/data/endpoints.dart';
import 'package:mesh_app/data/map_tiles.dart';
import 'package:mesh_app/data/offline_map.dart';
import 'package:mesh_app/data/offline_map_store.dart';

import 'map_pmtiles_fixture.dart';

final _map = base64Decode(pmtilesSimple);
const _modified = 'Thu, 01 Oct 2026 10:00:00 GMT';

/// A Node that serves [body] in [chunks] pieces, like a slow Wi-Fi link.
MockClient _node(
  Uint8List body, {
  int status = 200,
  int chunks = 4,
  String lastModified = _modified,
  List<http.BaseRequest>? asked,
}) =>
    MockClient.streaming((request, _) async {
      asked?.add(request);
      final headers = {
        'content-length': '${body.length}',
        'last-modified': lastModified,
        'content-type': 'application/vnd.pmtiles',
      };
      if (request.method == 'HEAD') {
        return http.StreamedResponse(const Stream.empty(), status, headers: headers);
      }
      final size = (body.length / chunks).ceil();
      return http.StreamedResponse(
        Stream.fromIterable([
          for (var i = 0; i < body.length; i += size)
            body.sublist(i, i + size > body.length ? body.length : i + size),
        ]),
        status,
        contentLength: status == 200 ? body.length : null,
        headers: headers,
      );
    });

/// A Node that never answers.
MockClient _silent() => MockClient((_) => Completer<http.Response>().future);

void main() {
  test('downloads from the Resilience Node with progress, then draws from it', () async {
    final asked = <http.BaseRequest>[];
    final map = OfflineMap(client: _node(_map, asked: asked), store: MemoryOfflineMapStore());
    addTearDown(map.dispose);
    final seen = <double?>[];
    map.addListener(() => seen.add(map.progress));

    await map.download();

    expect(asked.single.url.toString(), '$nodeBaseUrl/node/v1/map/san-jose.pmtiles');
    expect(seen.whereType<double>(), isNotEmpty);
    final steps = seen.whereType<double>().toList();
    expect(steps, orderedEquals([...steps]..sort()));
    expect(map.ready, isTrue);
    expect(map.downloading, isFalse);
    expect(map.problem, isNull);
    expect(map.info!.sizeBytes, _map.length);
    expect(map.info!.lastModified, _modified);
    expect(map.style(dark: false, languageCode: 'en'), isNotNull);
    expect(map.attribution, contains('OpenStreetMap'));
  });

  test('a build can name another download address', () {
    expect(
      offlineMapSource(url: 'https://maps.example.org/bay.pmtiles').toString(),
      'https://maps.example.org/bay.pmtiles',
    );
    expect(offlineMapSource(url: '', region: 'oakland').path, '/node/v1/map/oakland.pmtiles');
  });

  test('the saved map is found again when the app opens', () async {
    final store = MemoryOfflineMapStore();
    final first = OfflineMap(client: _node(_map), store: store);
    await first.download();
    first.dispose();

    final again = OfflineMap(client: _silent(), store: store);
    addTearDown(again.dispose);
    expect(again.ready, isFalse);
    await again.load();
    expect(again.ready, isTrue);
    expect(again.info!.sizeBytes, _map.length);
  });

  test('no map on the Node, or no Node at all, says why and keeps the old map', () async {
    final store = MemoryOfflineMapStore();
    final saved = OfflineMap(client: _node(_map), store: store);
    await saved.download();
    saved.dispose();

    final missing = OfflineMap(client: _node(Uint8List(0), status: 404), store: store);
    addTearDown(missing.dispose);
    await missing.download();
    expect(missing.problem, OfflineMapProblem.notFound);
    expect(missing.ready, isTrue, reason: 'the map already saved stays in use');

    final offline = OfflineMap(
      client: MockClient((_) async => throw http.ClientException('Network is unreachable')),
      store: MemoryOfflineMapStore(),
    );
    addTearDown(offline.dispose);
    await offline.download();
    expect((offline.problem, offline.ready, offline.downloading),
        (OfflineMapProblem.unreachable, false, false));
  });

  test('a Node that never answers times out instead of spinning forever', () async {
    final map = OfflineMap(
      client: _silent(),
      store: MemoryOfflineMapStore(),
      connectTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(map.dispose);
    await map.download();
    expect(map.problem, OfflineMapProblem.unreachable);
    expect(map.downloading, isFalse);
  });

  test('a file that is not a street map is refused and nothing is saved', () async {
    final page = Uint8List.fromList(utf8.encode('<html>Captive portal: sign in</html>' * 10));
    final store = MemoryOfflineMapStore();
    final map = OfflineMap(client: _node(page), store: store);
    addTearDown(map.dispose);
    await map.download();
    expect(map.problem, OfflineMapProblem.notAMap);
    expect(map.ready, isFalse);
    expect(await store.info(), isNull);
  });

  test('stopping a download keeps nothing and leaves the old map in use', () async {
    final store = MemoryOfflineMapStore();
    final fresh = OfflineMap(client: _node(_map, chunks: 8), store: store);
    addTearDown(fresh.dispose);
    fresh.addListener(() {
      if (fresh.downloading && fresh.receivedBytes > 0) fresh.cancel();
    });
    await fresh.download();
    expect(fresh.ready, isFalse);
    expect(fresh.problem, isNull);
    expect(await store.info(), isNull);

    // With a map saved, stopping an update keeps that map.
    final saved = OfflineMap(client: _node(_map), store: store);
    await saved.download();
    saved.dispose();
    final update = OfflineMap(
      client: _node(_map, chunks: 8, lastModified: 'Fri, 02 Oct 2026 10:00:00 GMT'),
      store: store,
    );
    addTearDown(update.dispose);
    await update.load();
    update.addListener(() {
      if (update.downloading && update.receivedBytes > 0) update.cancel();
    });
    await update.download();
    expect(update.ready, isTrue);
    expect(update.info!.lastModified, _modified);
    expect((await store.info())!.lastModified, _modified);
  });

  test('a newer map on the Node shows as an update; the same one does not', () async {
    final store = MemoryOfflineMapStore();
    final map = OfflineMap(client: _node(_map), store: store);
    await map.download();
    await map.checkForUpdate();
    expect(map.updateAvailable, isFalse);
    map.dispose();

    final asked = <http.BaseRequest>[];
    final newer = OfflineMap(
      client: _node(_map, lastModified: 'Fri, 02 Oct 2026 10:00:00 GMT', asked: asked),
      store: store,
    );
    addTearDown(newer.dispose);
    await newer.load();
    await newer.checkForUpdate();
    expect(asked.single.method, 'HEAD', reason: 'checking downloads nothing');
    expect(newer.updateAvailable, isTrue);

    await newer.download();
    expect(newer.updateAvailable, isFalse);
    expect(newer.info!.lastModified, 'Fri, 02 Oct 2026 10:00:00 GMT');
  });

  test('deleting removes the map from the phone', () async {
    final store = MemoryOfflineMapStore();
    final map = OfflineMap(client: _node(_map), store: store);
    addTearDown(map.dispose);
    await map.download();
    await map.delete();
    expect(map.ready, isFalse);
    expect(map.style(dark: false, languageCode: 'en'), isNull);
    expect(await store.info(), isNull);
  });

  group('which street map shows', () {
    MapTiles amazon({required bool works}) => MapTiles(
          key: 'k1',
          client: MockClient((request) async {
            if (!works) throw http.ClientException('offline');
            if (!request.url.path.endsWith('/descriptor')) return http.Response('', 404);
            return http.Response(
              jsonEncode({
                'version': 8,
                'sources': {
                  'aws': {'type': 'vector', 'tiles': ['https://example.org/{z}/{x}/{y}'], 'maxzoom': 15},
                },
                'layers': [
                  {'id': 'background', 'type': 'background', 'paint': {'background-color': '#ffffff'}},
                ],
              }),
              200,
            );
          }),
        );

    test('Amazon while it works, the offline map when it does not', () async {
      final offline = OfflineMap(client: _node(_map), store: MemoryOfflineMapStore());
      addTearDown(offline.dispose);
      await offline.download();

      final online = amazon(works: true);
      addTearDown(online.dispose);
      await online.open(dark: false, languageCode: 'en');
      expect(pickStreetMap(online, offline, dark: false, languageCode: 'en').$1, StreetMap.online);

      final down = amazon(works: false);
      addTearDown(down.dispose);
      await down.open(dark: false, languageCode: 'en');
      final (kind, style) = pickStreetMap(down, offline, dark: false, languageCode: 'en');
      expect(kind, StreetMap.offline);
      expect(style, same(offline.style(dark: false, languageCode: 'en')));

      final noKey = MapTiles(key: '', client: _silent());
      addTearDown(noKey.dispose);
      expect(pickStreetMap(noKey, offline, dark: true, languageCode: 'es').$1, StreetMap.offline);
    });

    test('neither: pins on a plain background', () async {
      final offline = OfflineMap(client: _silent(), store: MemoryOfflineMapStore());
      addTearDown(offline.dispose);
      await offline.load();
      final down = amazon(works: false);
      addTearDown(down.dispose);
      await down.open(dark: false, languageCode: 'en');
      expect(pickStreetMap(down, offline, dark: false, languageCode: 'en'), (StreetMap.none, null));
    });
  });
}
