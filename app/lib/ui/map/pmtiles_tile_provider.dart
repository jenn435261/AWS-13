import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pmtiles/pmtiles.dart';

/// A web-safe flutter_map [TileProvider] that renders raster tiles straight out
/// of a PMTiles archive served by a Resilience Node at
/// `GET /node/v1/map/{region}.pmtiles` (HTTP Range supported).
///
/// Why this approach is web-safe:
///  * The `pmtiles` package reads a remote archive over plain HTTP Range
///    requests (`PmTilesArchive.fromUri`), which is supported on the dart2js
///    web build (see the package's support matrix: HTTP = Yes on Browsers).
///  * We only ever decode RASTER tiles (png / jpeg / webp) with the Flutter
///    engine's own image decoder (`ImmutableBuffer.fromUint8List`). We do NOT
///    pull in a vector tile renderer, and crucially we do NOT add
///    `maplibre_gl` (its web plugin breaks `flutter build web --release`).
///  * Vector archives (mvt / mlt) are reported as unsupported via
///    [openRaster] returning null, so the map screen transparently keeps the
///    online OpenStreetMap raster layer and the honest offline banner instead
///    of silently showing nothing.
///
/// The archive is opened once and its directory/header reads are cached by the
/// `pmtiles` package, so only the handful of tiles actually on screen are
/// fetched (each as a small Range request against the node).
class PmTilesTileProvider extends TileProvider {
  PmTilesTileProvider._(this._archive);

  final PmTilesArchive _archive;

  /// Opens [url] and returns a provider ONLY when the archive is raster
  /// (png/jpeg/webp). Returns null for vector archives, unknown types, or any
  /// network/parse failure, so the caller can fall back to OSM raster tiles.
  static Future<PmTilesTileProvider?> openRaster(String url) async {
    try {
      final archive = await PmTilesArchive.fromUri(Uri.parse(url));
      switch (archive.tileType) {
        case TileType.png:
        case TileType.jpeg:
        case TileType.webp:
          return PmTilesTileProvider._(archive);
        default:
          // Vector (mvt/mlt) or unknown: we do not ship a vector renderer and
          // must not add maplibre_gl, so report unsupported.
          await archive.close();
          return null;
      }
    } catch (_) {
      return null; // unreachable node, missing region, corrupt archive, etc.
    }
  }

  /// The zoom range the archive actually covers, so the TileLayer can clamp.
  int get minZoom => _archive.minZoom;
  int get maxZoom => _archive.maxZoom;

  @override
  ImageProvider<Object> getImage(
          TileCoordinates coordinates, TileLayer options) =>
      _PmTilesImageProvider(
        archive: _archive,
        z: coordinates.z,
        x: coordinates.x,
        y: coordinates.y,
      );

  @override
  void dispose() {
    unawaited(_archive.close());
    super.dispose();
  }
}

/// Decodes a single PMTiles raster tile into a Flutter image. A missing tile
/// resolves to a transparent image (so gaps outside the archive bounds are
/// blank rather than error-filled), mirroring flutter_map's own behavior.
@immutable
class _PmTilesImageProvider extends ImageProvider<_PmTilesImageProvider> {
  const _PmTilesImageProvider({
    required this.archive,
    required this.z,
    required this.x,
    required this.y,
  });

  final PmTilesArchive archive;
  final int z;
  final int x;
  final int y;

  @override
  Future<_PmTilesImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_PmTilesImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
      _PmTilesImageProvider key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(
      _load(decode),
      informationCollector: () =>
          [DiagnosticsProperty('Tile', 'pmtiles z$z/$x/$y')],
    );
  }

  Future<ImageInfo> _load(ImageDecoderCallback decode) async {
    Uint8List bytes;
    try {
      final tile = await archive.tile(ZXY(z, x, y).toTileId());
      bytes = Uint8List.fromList(tile.bytes());
    } catch (_) {
      // No such tile (outside bounds) or read error: draw nothing.
      bytes = TileProvider.transparentImage;
    }
    final buffer = await ImmutableBuffer.fromUint8List(bytes);
    final codec = await decode(buffer);
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _PmTilesImageProvider &&
          identical(other.archive, archive) &&
          other.z == z &&
          other.x == x &&
          other.y == y);

  @override
  int get hashCode => Object.hash(identityHashCode(archive), z, x, y);
}
