import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_app/data/offline_map_pmtiles.dart';
import 'package:mesh_app/data/offline_map_store.dart';
import 'package:mesh_app/data/offline_map_store_io.dart';
import 'package:mesh_app/data/offline_map_theme.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' show TileIdentity;
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

import 'map_pmtiles_fixture.dart';

Uint8List _bytes(String b64) => base64Decode(b64);

/// Counts reads, to see what the reader keeps instead of reading again.
class _CountingSource extends MemoryPmTilesSource {
  _CountingSource(super.bytes);

  final reads = <(int, int)>[];

  @override
  Future<Uint8List> read(int offset, int length) {
    reads.add((offset, length));
    return super.read(offset, length);
  }
}

/// Collects what the style reader could not use.
class _Warnings implements Logger {
  final messages = <String>[];

  @override
  void log(MessageFunction message) {}

  @override
  void warn(MessageFunction message) => messages.add(message());
}

void main() {
  test('tile numbers match the reference implementation', () {
    for (final (z, x, y, id) in referenceTileIds) {
      expect(pmTilesTileId(z, x, y), id, reason: '$z/$x/$y');
    }
    expect(() => pmTilesTileId(1, 2, 0), throwsA(isA<PmTilesException>()));
  });

  test('reads the header: vector tiles, gzip, zooms and the area covered', () async {
    final archive = await PmTilesArchive.open(MemoryPmTilesSource(_bytes(pmtilesSimple)));
    final h = archive.header;
    expect(h.tileType, PmTilesTileType.mvt);
    expect(h.tileCompression, PmTilesCompression.gzip);
    expect(h.internalCompression, PmTilesCompression.gzip);
    expect((h.minZoom, h.maxZoom, h.centerZoom), (0, 14, 14));
    expect(h.center.$1, closeTo(-121.8811, 1e-6));
    expect(h.center.$2, closeTo(37.3352, 1e-6));
    expect(h.bounds.$1, lessThan(h.bounds.$3));
    expect(h.bounds.$2, lessThan(h.bounds.$4));
  });

  for (final (name, fixture) in [('one index', pmtilesSimple), ('leaf indexes', pmtilesWithLeaves)]) {
    group('with $name', () {
      late PmTilesArchive archive;
      setUp(() async => archive = await PmTilesArchive.open(MemoryPmTilesSource(_bytes(fixture))));

      test('a tile comes back unpacked, byte for byte', () async {
        final (z, x, y) = streetTileZxy;
        expect(await archive.tile(z, x, y), _bytes(streetTile));
        expect(await archive.tile(0, 0, 0), _bytes(earthTile));
      });

      test('tiles stored once for a whole run all come back', () async {
        for (final (z, x, y) in runTiles) {
          expect(await archive.tile(z, x, y), _bytes(earthTile), reason: '$z/$x/$y');
        }
      });

      test('a tile the archive does not have is null, as are other zooms', () async {
        final (z, x, y) = streetTileZxy;
        expect(await archive.tile(z, x + 3, y), isNull);
        expect(await archive.tile(1, 0, 0), isNull);
        expect(await archive.tile(15, x * 2, y * 2), isNull);
      });

      test('the metadata names the layers and credits OpenStreetMap', () async {
        expect(await archive.layerNames(), {'earth', 'landuse', 'water', 'roads', 'places'});
        expect('${(await archive.metadata())['attribution']}', contains('OpenStreetMap'));
      });
    });
  }

  test('a leaf index is read once, then reused', () async {
    final source = _CountingSource(_bytes(pmtilesWithLeaves));
    final archive = await PmTilesArchive.open(source);
    final (z, x, y) = streetTileZxy;
    await archive.tile(z, x, y);
    final first = source.reads.length;
    await archive.tile(z, x, y);
    // Only the tile itself is read the second time.
    expect(source.reads.length, first + 1);
    expect(archive.header.leafLength, greaterThan(0));
  });

  test('a file that is not a PMTiles map is refused', () async {
    final html = Uint8List.fromList(utf8.encode('<html>${' ' * 200}</html>'));
    expect(PmTilesArchive.open(MemoryPmTilesSource(html)), throwsA(isA<PmTilesException>()));
    final v2 = _bytes(pmtilesSimple)..[7] = 2;
    expect(PmTilesArchive.open(MemoryPmTilesSource(v2)), throwsA(isA<PmTilesException>()));
  });

  test('the map gets an empty tile, not an error, where the archive has none', () async {
    final archive = await PmTilesArchive.open(MemoryPmTilesSource(_bytes(pmtilesSimple)));
    final provider = PmTilesVectorTileProvider(archive);
    final (z, x, y) = streetTileZxy;
    expect((provider.minimumZoom, provider.maximumZoom), (0, 14));
    expect(await provider.provide(TileIdentity(z, x, y)), _bytes(streetTile));
    expect(await provider.provide(TileIdentity(z, x + 3, y)), isEmpty);
    // An empty tile is still a valid vector tile.
    expect(VectorTileReader().read(Uint8List(0)).layers, isEmpty);
  });

  group('the offline style', () {
    for (final schema in OfflineMapSchema.values) {
      for (final dark in [false, true]) {
        test('${schema.name}${dark ? ', dark' : ''}: every rule is readable', () {
          final warnings = _Warnings();
          final style = offlineMapStyle(schema: schema, dark: dark, languageCode: 'vi');
          final theme = ThemeReader(logger: warnings).read(style);
          expect(warnings.messages, isEmpty);
          expect(theme.layers, hasLength((style['layers'] as List).length));
          expect(theme.layers.length, greaterThan(10));
        });
      }
    }

    test('the schema is told apart by its layer names', () {
      expect(OfflineMapSchema.of({'earth', 'roads', 'water'}), OfflineMapSchema.protomaps);
      expect(OfflineMapSchema.of({'transportation', 'water', 'place'}), OfflineMapSchema.openMapTiles);
      expect(OfflineMapSchema.of({}), OfflineMapSchema.protomaps);
    });

    test('labels are 16 px or larger, in the app language first', () {
      final style = offlineMapStyle(schema: OfflineMapSchema.protomaps, dark: false, languageCode: 'zh');
      final symbols = [
        for (final l in style['layers'] as List)
          if (l['type'] == 'symbol') l as Map,
      ];
      expect(symbols, isNotEmpty);
      for (final s in symbols) {
        expect(s['layout']['text-size'], greaterThanOrEqualTo(16));
        expect(s['layout']['text-field'], [
          'coalesce',
          ['get', 'name:zh-Hans'],
          ['get', 'name:zh'],
          ['get', 'name'],
        ]);
      }
    });

    testWidgets('draws water, parks and streets from the package', (tester) async {
      final pixels = await tester.runAsync(() async {
        final theme = ThemeReader().read(
          offlineMapStyle(schema: OfflineMapSchema.protomaps, dark: false, languageCode: 'en'),
        );
        final tile = VectorTileReader().read(_bytes(streetTile));
        final image = await ImageRenderer(theme: theme, scale: 1).render(
          TileSource(tileset: Tileset({offlineMapSourceId: TileFactory(theme, const Logger.noop()).create(tile)})),
          zoom: 16,
        );
        return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      });
      Color at(int x, int y) {
        final i = (y * 256 + x) * 4;
        return Color.fromARGB(
          pixels!.getUint8(i + 3),
          pixels.getUint8(i),
          pixels.getUint8(i + 1),
          pixels.getUint8(i + 2),
        );
      }

      // Tile coordinates are 0-4096; the image is 256 pixels across.
      expect(at(220, 220), const Color(0xFFB7D0E8), reason: 'water');
      expect(at(40, 40), const Color(0xFFD3E8CC), reason: 'park');
      expect(at(200, 80), const Color(0xFFEEF0F3), reason: 'land');
      // Streets, away from where their names are written.
      expect(at(16, 128), const Color(0xFFFFFFFF), reason: 'main street');
      expect(at(128, 16), const Color(0xFFFFFFFF), reason: 'side street');
      expect(at(16, 136), isNot(const Color(0xFFFFFFFF)), reason: 'beside the street');
    });
  });

  group('on the phone', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('mesh_map'));
    tearDown(() async => dir.delete(recursive: true));

    test('a finished download replaces the saved map; delete removes it', () async {
      final store = FileOfflineMapStore(directory: () async => dir);
      expect(await store.info(), isNull);

      final upload = await store.begin();
      final bytes = _bytes(pmtilesSimple);
      await upload.add(bytes.sublist(0, 100));
      await upload.add(bytes.sublist(100));
      final check = await upload.open();
      expect((await PmTilesArchive.open(check)).header.maxZoom, 14);
      await check.close();
      final info = OfflineMapInfo(
        sizeBytes: bytes.length,
        downloadedAt: DateTime(2026, 10, 1),
        source: 'http://node/map.pmtiles',
        lastModified: 'Thu, 01 Oct 2026 10:00:00 GMT',
      );
      await store.commit(upload, info);

      final saved = await store.info();
      expect(saved?.sizeBytes, bytes.length);
      expect(saved?.lastModified, info.lastModified);
      final archive = await PmTilesArchive.open(await store.open());
      final (z, x, y) = streetTileZxy;
      // Reads from one file handle, asked for at the same time, all succeed.
      final tiles = await Future.wait([for (var i = 0; i < 5; i++) archive.tile(z, x, y)]);
      expect(tiles.every((t) => listEquals(t, _bytes(streetTile))), isTrue);
      await archive.close();
      expect(dir.listSync().map((f) => f.uri.pathSegments.last), isNot(contains(endsWith('.part'))));

      await store.delete();
      expect(await store.info(), isNull);
    });

    test('a stopped download leaves nothing behind', () async {
      final store = FileOfflineMapStore(directory: () async => dir);
      final upload = await store.begin();
      await upload.add([1, 2, 3]);
      await upload.abort();
      expect(dir.listSync(), isEmpty);
      expect(await store.info(), isNull);
    });
  });
}
