import 'haptic_kind.dart';
import 'platform_haptics_stub.dart'
    if (dart.library.io) 'platform_haptics_native.dart'
    if (dart.library.js_interop) 'platform_haptics_web.dart';

export 'haptic_kind.dart';

/// The platform vibration sink. Production wires this to the conditional-import
/// backend; tests pass a recording closure to assert gating without a channel.
typedef HapticSink = void Function(HapticKind kind);

/// Fires haptic feedback, gated by a caller-supplied [enabled] flag (wired to
/// the Settings "Haptic feedback" toggle). When disabled this is a guaranteed
/// no-op — it never touches the platform channel.
///
/// The actual platform call is behind a conditional import: native uses
/// Flutter's `HapticFeedback`, web uses `navigator.vibrate` where supported and
/// silently skips otherwise. Nothing here ever throws into the UI.
class Haptics {
  const Haptics({HapticSink? sink}) : _sink = sink;

  final HapticSink? _sink;

  void fire(HapticKind kind, {required bool enabled}) {
    if (!enabled) return;
    try {
      final sink = _sink;
      if (sink != null) {
        sink(kind);
      } else {
        const PlatformHaptics().vibrate(kind);
      }
    } catch (_) {
      // Haptics are best-effort feedback; a platform that cannot vibrate must
      // never break the action that triggered it.
    }
  }
}
