import 'dart:async';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../position_service.dart';
import 'estimate.dart';

/// Native dead-reckoner: coasts from the last good fix using the device motion
/// sensors (accelerometer) to approximate how far the user has moved, with an
/// uncertainty radius that grows with distance and elapsed time
/// ([estimatedUncertaintyRadiusM]).
///
/// This is deliberately conservative: step/displacement from a phone
/// accelerometer is noisy, so we treat motion as a coarse "have we moved"
/// signal and let the uncertainty radius widen quickly. The result is ALWAYS
/// labelled "estimated" and never presented as a GPS fix; accepting it stamps
/// an event with location_source = ESTIMATED.
/// Whether dead-reckoning is available on this platform, WITHOUT constructing a
/// reckoner (so a UI probe never starts a sensor stream). True on native.
bool deadReckoningAvailable() => true;

class DeadReckoner {
  DeadReckoner() {
    _sub = accelerometerEventStream().listen(_onSample, onError: (_) {});
  }

  StreamSubscription<AccelerometerEvent>? _sub;

  /// Accumulated |acceleration - g| integrated over time, a proxy for distance.
  double _motionProxyM = 0;
  DateTime? _lastSample;

  static const double _g = 9.81;

  bool get isAvailable => true;

  void _onSample(AccelerometerEvent e) {
    final now = DateTime.now();
    final prev = _lastSample;
    _lastSample = now;
    if (prev == null) return;
    final dt = now.difference(prev).inMilliseconds / 1000.0;
    if (dt <= 0 || dt > 1) return; // ignore gaps/outliers
    final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final net = (mag - _g).abs();
    // Deadband to suppress sensor noise when stationary.
    if (net < 0.6) return;
    // Very rough displacement proxy: net accel * dt^2. Intentionally small; the
    // uncertainty radius, not this value, carries the honesty.
    _motionProxyM += net * dt * dt;
  }

  DeadReckonEstimate? estimate(LastFix from) {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final since = Duration(milliseconds: nowMs - from.takenAtMs);
    final radius = estimatedUncertaintyRadiusM(
      baseAccuracyM: from.accuracyM ?? 30,
      distanceWalkedM: _motionProxyM,
      elapsed: since,
    );
    // We do not have a reliable heading, so the estimated point stays at the
    // last fix and the GROWING radius expresses the uncertainty honestly.
    return DeadReckonEstimate(
      point: LatLng(from.lat, from.lon),
      radiusM: radius,
      since: since,
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
