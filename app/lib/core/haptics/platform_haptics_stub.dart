import 'haptic_kind.dart';

/// Fallback backend for platforms that are neither dart:io (native) nor web.
/// There is no vibration primitive to call, so this silently does nothing.
/// Used by the pure-Dart test VM.
class PlatformHaptics {
  const PlatformHaptics();

  void vibrate(HapticKind kind) {
    // No platform vibration available: silently skip (honest no-op).
  }
}
