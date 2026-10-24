import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/ui/map/pmtiles_tile_provider.dart';

void main() {
  // The gating property for Item E is that the web build keeps compiling; the
  // render path itself is exercised by the browser click-through + web build.
  // Here we assert the one piece of app logic that is testable without a real
  // archive: an unreachable / invalid PMTiles URL yields null so the map view
  // transparently keeps the online OSM raster fallback (and its honest offline
  // banner) rather than showing a blank map.
  group('PmTilesTileProvider.openRaster', () {
    test('unreachable node URL -> null (OSM fallback)', () async {
      final p = await PmTilesTileProvider.openRaster(
          'http://127.0.0.1:1/node/v1/map/none.pmtiles');
      expect(p, isNull);
    });

    test('garbage URL -> null, never throws', () async {
      final p = await PmTilesTileProvider.openRaster('not a url');
      expect(p, isNull);
    });
  });
}
