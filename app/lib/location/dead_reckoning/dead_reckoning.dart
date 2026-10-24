// Platform-conditional dead-reckoning (estimated position) seam.
//
// Dead-reckoning needs device motion sensors (accelerometer/compass), which
// only exist on native. The web build MUST NOT import sensors_plus, so web gets
// the stub that honestly reports "unavailable". See docs/DECISIONS.md
// (Round 2 / FEAT-002): we never present an estimate as a GPS fix, and when
// the user accepts an estimate the event's location_source is ESTIMATED.
export 'stub.dart' if (dart.library.io) 'native.dart';
