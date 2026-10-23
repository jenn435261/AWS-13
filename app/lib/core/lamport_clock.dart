import 'package:fixnum/fixnum.dart';

/// A Lamport logical clock.
///
/// Causal ordering in the Resilience Network is driven by a per-author Lamport
/// clock (a uint64). Device wall-clocks are untrustworthy during a disaster, so
/// ordering must not depend on them. The clock rules are the classic Lamport
/// construction:
///
/// * [observe] is called for every event we *see* (local or remote). It raises
///   the internal counter to `max(current, seen)`, ensuring our next event will
///   sort after everything we have already witnessed.
/// * [tick] is called when we *create* a new event. It increments the counter
///   and returns the new value (`max(all seen) + 1`), guaranteeing strict
///   monotonicity per author.
///
/// The counter is a uint64 held in a [Int64]. The value is persistable: read it
/// with [current] and restore it with [load] so the clock survives restarts.
class LamportClock {
  Int64 _counter;

  LamportClock([Int64? initial]) : _counter = initial ?? Int64.ZERO {
    _checkNonNegative(_counter);
  }

  /// Constructs a clock from an unsigned integer value.
  factory LamportClock.fromInt(int value) =>
      LamportClock(Int64(value));

  /// The current counter value. Persist this to survive restarts.
  Int64 get current => _counter;

  /// The current value as a plain Dart [int] (safe for values < 2^63).
  int get currentAsInt => _counter.toInt();

  /// Restores the clock to a previously persisted [value].
  ///
  /// This is a hard set used on startup; it does not apply the `max` rule.
  void load(Int64 value) {
    _checkNonNegative(value);
    _counter = value;
  }

  /// Observes a [seen] Lamport value (from a received or stored event) and
  /// raises the counter to `max(current, seen)`.
  ///
  /// Comparison is unsigned so the full uint64 range orders correctly.
  void observe(Int64 seen) {
    _checkNonNegative(seen);
    if (_unsignedGreaterThan(seen, _counter)) {
      _counter = seen;
    }
  }

  /// Convenience overload of [observe] taking a plain [int].
  void observeInt(int seen) => observe(Int64(seen));

  /// Advances the clock for a newly created local event and returns the new
  /// value (`max(all seen) + 1`).
  Int64 tick() {
    _counter += Int64.ONE;
    return _counter;
  }

  static void _checkNonNegative(Int64 v) {
    // Values are conceptually unsigned uint64. We reject negatives (which would
    // indicate a mis-encoded/overflowed value) to fail loudly.
    if (v.isNegative) {
      throw ArgumentError.value(
          v, 'value', 'Lamport clock values must be non-negative (uint64)');
    }
  }

  /// Unsigned comparison for the uint64 domain. Because we forbid negative
  /// values via [_checkNonNegative], a plain signed compare is equivalent here,
  /// but we keep the intent explicit.
  static bool _unsignedGreaterThan(Int64 a, Int64 b) => a > b;
}
