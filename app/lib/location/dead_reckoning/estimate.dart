import 'package:latlong2/latlong.dart';

import '../position_service.dart';

/// A dead-reckoned ("estimated") position: a best-guess point with an honest
/// uncertainty radius that grows the longer we coast without a real fix. It is
/// NEVER a GPS fix; the UI labels it "estimated" and an event built from an
/// accepted estimate carries location_source = ESTIMATED.
class DeadReckonEstimate {
  /// The estimated point (local only; rounded to ~110 m by [geoPointFor] before
  /// any event is built).
  final LatLng point;

  /// The uncertainty radius in metres (see [estimatedUncertaintyRadiusM]).
  final double radiusM;

  /// How long since the last good fix this estimate coasted from.
  final Duration since;

  const DeadReckonEstimate({
    required this.point,
    required this.radiusM,
    required this.since,
  });
}
