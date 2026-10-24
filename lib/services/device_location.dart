import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/mesh_repository.dart';
import '../models/help.dart';

/// Feeds the phone's real GPS into the repository.
///
/// Every failure (location off, permission denied, the web build on plain
/// http) just means no fix: the request flow then asks people to describe
/// where they are, which is the manual fallback.
class DeviceLocation {
  DeviceLocation(this._repository);

  final MeshRepository _repository;
  StreamSubscription<Position>? _updates;

  Future<void> start() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // One quick fix first, then updates as the phone moves.
      final first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _report(first);

      _updates = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
        ),
      ).listen(_report, onError: (Object _) {});
    } catch (_) {
      // No fix; the manual location note still works.
    }
  }

  void _report(Position p) => _repository.reportLocation(
        LocationFix(LatLng(p.latitude, p.longitude), p.accuracy),
      );

  Future<void> dispose() async => _updates?.cancel();
}
