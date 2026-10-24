import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/help.dart';

/// Where the phone's own position comes from. The repository listens to
/// one of these; screens never talk to GPS directly.
abstract class LocationProvider {
  /// Starts reporting: a fix whenever the phone moves, and null whenever
  /// location is denied, switched off or unavailable. Asking for
  /// permission happens here, once.
  Stream<LocationFix?> watch();
}

/// GPS is "accurate" at this radius or better. Only then does a reading
/// replace a location the person typed or dropped on the map.
const accurateGpsMeters = 20.0;

/// The rule for a manual location, in one place:
///
/// A location the person set by hand stays until they clear it, or until
/// GPS reports a fix accurate to [accurateGpsMeters] or better. People type
/// a location when GPS is poor (indoors, under cover); a poor reading
/// later must not undo that, but a clearly good one means the phone knows
/// better now, and the manual location is dropped for good.
///
/// Returns the location to show and whether the manual one still stands.
({LocationFix? shown, LocationFix? manual}) chooseLocation({
  LocationFix? manual,
  LocationFix? device,
}) {
  if (manual == null) return (shown: device, manual: null);
  if (device != null && device.accuracyMeters <= accurateGpsMeters) {
    return (shown: device, manual: null);
  }
  return (shown: manual, manual: manual);
}

/// The phone's GPS, through the geolocator plugin.
///
/// Asks politely: only for "while using the app", only once, and only when
/// the app starts watching. If the person says no, or location is off, it
/// reports null and the map offers to type a location instead. It never
/// asks again after a "don't ask again"; the person can change it in the
/// phone's settings.
class DeviceLocationProvider implements LocationProvider {
  DeviceLocationProvider({GeolocatorPlatform? platform})
      : _platform = platform ?? GeolocatorPlatform.instance;

  final GeolocatorPlatform _platform;

  static const _settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  @override
  Stream<LocationFix?> watch() {
    late final StreamController<LocationFix?> out;
    StreamSubscription<Position>? positions;
    StreamSubscription<ServiceStatus>? service;
    var cancelled = false;
    var asked = false;

    Future<void> follow() async {
      await positions?.cancel();
      positions = null;
      try {
        if (!await _platform.isLocationServiceEnabled()) {
          if (!cancelled) out.add(null);
          return;
        }
        var permission = await _platform.checkPermission();
        if (permission == LocationPermission.denied && !asked) {
          asked = true;
          permission = await _platform.requestPermission();
        }
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          if (!cancelled) out.add(null);
          return;
        }
        if (cancelled) return;
        positions = _platform.getPositionStream(locationSettings: _settings).listen(
              (p) => out.add(LocationFix(
                LatLng(p.latitude, p.longitude),
                p.accuracy,
                source: LocationSource.device,
              )),
              // Switched off or lost: no fix until it comes back.
              onError: (Object _) => out.add(null),
            );
      } on Object {
        if (!cancelled) out.add(null);
      }
    }

    out = StreamController<LocationFix?>(
      onListen: () {
        follow();
        try {
          // Location turned back on in the phone's settings: start again.
          service = _platform.getServiceStatusStream().listen(
            (s) => s == ServiceStatus.enabled ? follow() : out.add(null),
            onError: (Object _) {},
          );
        } on Object {
          // Not every platform reports this; the position stream still does.
        }
      },
      onCancel: () async {
        cancelled = true;
        await positions?.cancel();
        await service?.cancel();
      },
    );
    return out.stream;
  }
}
