import 'dart:math' as math;

import 'package:fixnum/fixnum.dart';

import '../gen/resilience/v1/event.pb.dart';

/// Location-permission tiers (spec §28).
///
/// The *same* resource or mission exposes different detail to different
/// viewers. A [GeoPoint] always carries a coarse, broadcast-safe bucket
/// (`h3Cell` + jittered `approxLat`/`approxLon`). Exact coordinates
/// (`exactLat`/`exactLon`), the `address`, and the `hasExact` flag are only
/// revealed to a viewer who holds the relevant capability (e.g.
/// `MISSION_x_DRIVER`).
///
/// [LocationView.resolve] is the single choke point: given a full [GeoPoint]
/// and whether the viewer has exact access, it returns a [GeoPoint] with the
/// exact fields stripped when access is denied — only `h3`/approx survive — so
/// the exact location can never leak to an unauthorized viewer.
class LocationView {
  LocationView._(this.point, this.hasExactAccess);

  /// The (possibly redacted) point to show the viewer.
  final GeoPoint point;

  /// Whether this view resolved with exact access.
  final bool hasExactAccess;

  /// Resolve [full] for a viewer.
  ///
  /// * [hasExactAccess] `true` -> the point is returned intact (exact coords +
  ///   address + `hasExact`).
  /// * [hasExactAccess] `false` -> a redacted copy is returned carrying only
  ///   `h3Cell` + `approxLat`/`approxLon`; exact fields, address, and the
  ///   `hasExact` flag are cleared. If the source lacked an approximate point
  ///   but had exact coords, an approximate is derived via [roundApprox] so a
  ///   public viewer still gets a coarse bucket without the exact value.
  static LocationView resolve(
    GeoPoint full, {
    required bool hasExactAccess,
  }) {
    if (hasExactAccess) {
      return LocationView._(full.deepCopy(), true);
    }
    return LocationView._(publicProjection(full), false);
  }

  /// A human-readable description appropriate to the access tier.
  ///
  /// Exact access yields the street address (optionally with the free-text
  /// detail already baked into `address`, e.g. "742 Example St, rear
  /// entrance"). Public access yields a vague distance string derived from the
  /// approximate point relative to [fromLat]/[fromLon] when both are supplied,
  /// otherwise a generic "nearby" phrasing — never exact coordinates.
  String describe({double? fromLat, double? fromLon}) {
    if (hasExactAccess) {
      if (point.hasAddress() && point.address.isNotEmpty) {
        return point.address;
      }
      if (point.hasExactLat() && point.hasExactLon()) {
        return '${point.exactLat.toStringAsFixed(5)}, '
            '${point.exactLon.toStringAsFixed(5)}';
      }
      return 'exact location shared';
    }
    // Public tier: approximate distance only.
    if (fromLat != null &&
        fromLon != null &&
        point.hasApproxLat() &&
        point.hasApproxLon()) {
      final double miles = _haversineMiles(
        fromLat,
        fromLon,
        point.approxLat,
        point.approxLon,
      );
      return '~${_roundMiles(miles).toStringAsFixed(1)} miles away';
    }
    return 'approximate area only';
  }
}

/// Produce the broadcast-safe projection of [full]: a [GeoPoint] carrying only
/// the coarse bucket (`h3Cell`) and the approximate lat/lon. Exact coordinates,
/// address, and the `hasExact` flag are never copied.
///
/// If [full] has no approximate point of its own but does carry exact coords,
/// the approximate is synthesized by [roundApprox] so publishing still yields a
/// usable coarse location without leaking the exact value.
GeoPoint publicProjection(GeoPoint full) {
  final GeoPoint out = GeoPoint();
  if (full.hasH3Cell() && full.h3Cell != Int64.ZERO) {
    out.h3Cell = full.h3Cell;
  }
  if (full.hasApproxLat() && full.hasApproxLon()) {
    out.approxLat = full.approxLat;
    out.approxLon = full.approxLon;
  } else if (full.hasExactLat() && full.hasExactLon()) {
    out.approxLat = roundApprox(full.exactLat);
    out.approxLon = roundApprox(full.exactLon);
  }
  // Deliberately: no exactLat/exactLon, no address, hasExact stays false.
  return out;
}

/// Round a coordinate to a coarse grid for approximate publishing.
///
/// Rounds to [decimals] decimal places (default 2, ~1.1 km at the equator) so
/// the published value reveals only a neighborhood-scale area, never the exact
/// point. This is the helper used before broadcasting a location publicly.
double roundApprox(double coord, {int decimals = 2}) {
  final num factor = math.pow(10, decimals);
  return (coord * factor).roundToDouble() / factor;
}

double _roundMiles(double miles) {
  // Round to the nearest tenth of a mile, floored at 0.1 so we never claim a
  // precise "0.0 miles" from an approximate point.
  final double r = (miles * 10).roundToDouble() / 10;
  return r < 0.1 ? 0.1 : r;
}

double _haversineMiles(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadiusMiles = 3958.8;
  final double dLat = _deg2rad(lat2 - lat1);
  final double dLon = _deg2rad(lon2 - lon1);
  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMiles * c;
}

double _deg2rad(double deg) => deg * (math.pi / 180.0);
