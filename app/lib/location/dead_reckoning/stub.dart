import '../position_service.dart';
import 'estimate.dart';

/// Web/stub dead-reckoner: no device motion sensors are available in a browser,
/// so estimated position is honestly UNAVAILABLE here. [isAvailable] is false
/// and [estimate] always returns null; the UI shows a truthful "not available
/// in a browser" message instead of inventing a position.
/// Whether dead-reckoning is available on this platform, WITHOUT constructing a
/// reckoner (so a UI probe never starts a sensor stream). Always false on web.
bool deadReckoningAvailable() => false;

class DeadReckoner {
  DeadReckoner();

  /// Whether dead-reckoning can run on this platform. Always false on web.
  bool get isAvailable => false;

  /// Produces an estimate by coasting from [from] (the last good fix). Always
  /// null on web.
  DeadReckonEstimate? estimate(LastFix from) => null;

  void dispose() {}
}
