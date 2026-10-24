import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../gen/resilience/v1/event.pb.dart';

/// Why a position could not be read, so the UI can say something truthful.
enum PositionFailure { serviceOff, denied, deniedForever, timeout, unknown }

class PositionResult {
  final LatLng? position;
  final PositionFailure? failure;
  const PositionResult.ok(LatLng p)
      : position = p,
        failure = null;
  const PositionResult.fail(PositionFailure f)
      : position = null,
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
    return PositionResult.ok(LatLng(p.latitude, p.longitude));
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

GeoPoint geoPointFor(LatLng p, {bool exact = false}) {
  final g = GeoPoint(
      approxLat: roundCoord(p.latitude), approxLon: roundCoord(p.longitude));
  if (exact) {
    g.exactLat = p.latitude;
    g.exactLon = p.longitude;
    g.hasExact = true;
  }
  return g;
}

/// The point to plot for a [GeoPoint], or null when it carries no position.
LatLng? latLngOf(GeoPoint? g) {
  if (g == null) return null;
  if (g.approxLat == 0 && g.approxLon == 0) return null;
  return LatLng(g.approxLat, g.approxLon);
}
