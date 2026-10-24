import 'dart:math';

import 'package:latlong2/latlong.dart';

/// A made-up neighborhood for the demo map, so the map works with no
/// internet and no downloaded tiles. Centered near SJSU; the streets are
/// illustrative, not real.
const demoCenter = LatLng(37.3352, -121.8811);

const _metersPerDegree = 111320.0;

/// The point [north] and [east] meters away from [from].
LatLng offsetMeters(LatLng from, double north, double east) => LatLng(
      from.latitude + north / _metersPerDegree,
      from.longitude +
          east / (_metersPerDegree * cos(from.latitude * pi / 180)),
    );

class DemoArea {
  const DemoArea({
    required this.blocks,
    required this.parks,
    required this.campus,
    required this.mainRoads,
  });

  final List<List<LatLng>> blocks;
  final List<List<LatLng>> parks;
  final List<LatLng> campus;
  final List<List<LatLng>> mainRoads;
}

DemoArea buildDemoArea({LatLng center = demoCenter}) {
  const cols = 11, rows = 9;
  const blockW = 120.0, blockH = 90.0, street = 22.0;
  const pitchX = blockW + street, pitchY = blockH + street;
  const originX = -cols * pitchX / 2, originY = -rows * pitchY / 2;

  List<LatLng> rect(double x, double y, double w, double h) => [
        offsetMeters(center, y, x),
        offsetMeters(center, y, x + w),
        offsetMeters(center, y + h, x + w),
        offsetMeters(center, y + h, x),
      ];

  // Blocks that become parks, and the 3x2 blocks that form the campus.
  const parkCells = {(1, 6), (8, 1), (9, 2)};
  bool inCampus(int c, int r) => c >= 4 && c <= 6 && r >= 3 && r <= 4;

  final blocks = <List<LatLng>>[];
  final parks = <List<LatLng>>[];
  for (var c = 0; c < cols; c++) {
    for (var r = 0; r < rows; r++) {
      if (inCampus(c, r)) continue;
      final cell = rect(originX + c * pitchX, originY + r * pitchY, blockW, blockH);
      (parkCells.contains((c, r)) ? parks : blocks).add(cell);
    }
  }

  final campus = rect(
    originX + 4 * pitchX,
    originY + 3 * pitchY,
    3 * pitchX - street,
    2 * pitchY - street,
  );

  // Two wide avenues through the street gaps.
  final avenueY = originY + 5 * pitchY - street / 2;
  final avenueX = originX + 3 * pitchX - street / 2;
  final mainRoads = [
    [
      offsetMeters(center, avenueY, originX),
      offsetMeters(center, avenueY, -originX),
    ],
    [
      offsetMeters(center, originY, avenueX),
      offsetMeters(center, -originY, avenueX),
    ],
  ];

  return DemoArea(
    blocks: blocks,
    parks: parks,
    campus: campus,
    mainRoads: mainRoads,
  );
}
