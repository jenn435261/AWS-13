import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Where the demo data sits: San José State University. The street map
/// itself comes from Amazon Location Service (see map_tiles.dart).
const demoCenter = LatLng(37.3352, -121.8811);

const _metersPerDegree = 111320.0;

/// The point [north] and [east] meters away from [from].
LatLng offsetMeters(LatLng from, double north, double east) => LatLng(
      from.latitude + north / _metersPerDegree,
      from.longitude +
          east / (_metersPerDegree * cos(from.latitude * pi / 180)),
    );
