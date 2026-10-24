import 'dart:async';

/// Native stub: there is no web `navigator.onLine` here. We return null
/// ("unknown") so the connectivity model relies on the sync client's real
/// reachability measurement instead of guessing. A native-only radio plugin
/// (connectivity_plus) could fill this in, but it must never be imported into
/// the web build, so it is deliberately absent. See docs/DECISIONS.md.
class OnlineDetector {
  /// Current browser online flag, or null when not observable on this platform.
  bool? get isOnline => null;

  /// A stream of online/offline transitions. On native this never emits.
  Stream<bool> get changes => const Stream<bool>.empty();

  void dispose() {}
}
