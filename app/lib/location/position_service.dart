import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../gen/resilience/v1/event.pb.dart';

/// Why a position could not be read, so the UI can say something truthful.
enum PositionFailure { serviceOff, denied, deniedForever, timeout, unknown }

class PositionResult {
  final LatLng? position;
  final PositionFailure? failure;

  /// Reported horizontal accuracy in metres for a successful read, or null.
  final double? accuracyM;

  const PositionResult.ok(LatLng p, {this.accuracyM})
      : position = p,
        failure = null;
  const PositionResult.fail(PositionFailure f)
      : position = null,
        accuracyM = null,
        failure = f;
}

/// Reads the device position once, only when the user asks (never ambient
/// tracking). Works on web (browser permission prompt) and mobile.
Future<PositionResult> readPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const PositionResult.fail(PositionFailure.serviceOff);
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      return const PositionResult.fail(PositionFailure.deniedForever);
    }
    if (perm == LocationPermission.denied) {
      return const PositionResult.fail(PositionFailure.denied);
    }
    final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 12)));
    return PositionResult.ok(LatLng(p.latitude, p.longitude),
        accuracyM: p.accuracy);
  } on Exception catch (e) {
    final s = e.toString().toLowerCase();
    return PositionResult.fail(
        s.contains('time') ? PositionFailure.timeout : PositionFailure.unknown);
  }
}

/// The map's fallback centre when no position and no markers are available
/// (San Jose, the event location). Only a viewport default, never a claim
/// about where the user is.
const LatLng kDefaultMapCenter = LatLng(37.3382, -121.8863);

/// Privacy: shared points are rounded to 3 decimals (~110 m) unless the user
/// explicitly chooses to include an exact point.
double roundCoord(double v) => (v * 1000).roundToDouble() / 1000;

GeoPoint geoPointFor(
  LatLng p, {
  bool exact = false,
  LocationSource source = LocationSource.LOCATION_SOURCE_UNSPECIFIED,
}) {
  final g = GeoPoint(
      approxLat: roundCoord(p.latitude), approxLon: roundCoord(p.longitude));
  if (exact) {
    g.exactLat = p.latitude;
    g.exactLon = p.longitude;
    g.hasExact = true;
  }
  if (source != LocationSource.LOCATION_SOURCE_UNSPECIFIED) {
    g.locationSource = source;
  }
  return g;
}

/// A cached device fix persisted locally (never a coordinate in a log line).
/// The pair ([lat], [lon]) is kept at full precision ONLY in the local KeyValue
/// row; it is rounded to ~110 m by [geoPointFor] before any event is built.
class LastFix {
  /// Full-precision latitude (local only).
  final double lat;

  /// Full-precision longitude (local only).
  final double lon;

  /// Reported horizontal accuracy in metres, or null when the source did not
  /// report one.
  final double? accuracyM;

  /// Wall-clock epoch millis when this fix was taken.
  final int takenAtMs;

  const LastFix({
    required this.lat,
    required this.lon,
    required this.takenAtMs,
    this.accuracyM,
  });

  LatLng get position => LatLng(lat, lon);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lat': lat,
        'lon': lon,
        if (accuracyM != null) 'acc': accuracyM,
        'ts': takenAtMs,
      };

  static LastFix? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final lat = j['lat'];
    final lon = j['lon'];
    final ts = j['ts'];
    if (lat is! num || lon is! num || ts is! num) return null;
    final acc = j['acc'];
    return LastFix(
      lat: lat.toDouble(),
      lon: lon.toDouble(),
      takenAtMs: ts.toInt(),
      accuracyM: acc is num ? acc.toDouble() : null,
    );
  }

  /// A short "last known, `<age>`" age fragment (e.g. "2 min ago") computed
  /// against [nowMs]. Deliberately coarse so the UI never implies a live fix.
  String ageLabel(int nowMs) {
    final int ms = nowMs - takenAtMs;
    if (ms < 0) return 'just now';
    final int sec = ms ~/ 1000;
    if (sec < 60) return 'just now';
    final int min = sec ~/ 60;
    if (min < 60) return '$min min ago';
    final int hr = min ~/ 60;
    if (hr < 24) return '$hr hr ago';
    final int day = hr ~/ 24;
    return '$day day${day == 1 ? '' : 's'} ago';
  }
}

/// Dead-reckoning (native only): the uncertainty radius, in metres, of an
/// estimated position derived from the last good fix. It grows with both the
/// distance walked since the fix and the time elapsed, so the UI can draw an
/// honest "estimated" circle that visibly widens the longer we coast without a
/// real fix.
///
/// Pure logic (no sensors) so it is unit-testable. The model:
///   radius = baseAccuracy
///          + stepError  * distanceWalkedM
///          + driftPerMin * elapsedMinutes
/// clamped to [kMinEstimateRadiusM, kMaxEstimateRadiusM].
const double kMinEstimateRadiusM = 20;
const double kMaxEstimateRadiusM = 5000;

double estimatedUncertaintyRadiusM({
  required double baseAccuracyM,
  required double distanceWalkedM,
  required Duration elapsed,
  double stepErrorFraction = 0.15,
  double driftPerMinuteM = 8,
}) {
  final double base = baseAccuracyM <= 0 ? kMinEstimateRadiusM : baseAccuracyM;
  final double elapsedMin = elapsed.inMilliseconds / 60000.0;
  final double r = base +
      stepErrorFraction * (distanceWalkedM < 0 ? 0 : distanceWalkedM) +
      driftPerMinuteM * (elapsedMin < 0 ? 0 : elapsedMin);
  if (r < kMinEstimateRadiusM) return kMinEstimateRadiusM;
  if (r > kMaxEstimateRadiusM) return kMaxEstimateRadiusM;
  return r;
}

/// The point to plot for a [GeoPoint], or null when it carries no position.
LatLng? latLngOf(GeoPoint? g) {
  if (g == null) return null;
  if (g.approxLat == 0 && g.approxLon == 0) return null;
  return LatLng(g.approxLat, g.approxLon);
}
