import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'haptic_kind.dart';

/// Web haptics via the Vibration API where the browser supports it.
///
/// `navigator.vibrate(pattern)` is not in the typed `web` navigator surface, so
/// we reach it dynamically through `dart:js_interop_unsafe`. The Vibration API
/// exists only on some mobile browsers; on unsupported browsers the member is
/// absent and we silently skip (honest no-op, never an error).
class PlatformHaptics {
  const PlatformHaptics();

  void vibrate(HapticKind kind) {
    final nav = web.window.navigator as JSObject;
    // Feature-detect: only call vibrate when the browser actually exposes it.
    if (!nav.has('vibrate')) return;
    switch (kind) {
      case HapticKind.selection:
        nav.callMethod('vibrate'.toJS, 10.toJS);
      case HapticKind.confirm:
        nav.callMethod('vibrate'.toJS, 20.toJS);
      case HapticKind.success:
        nav.callMethod('vibrate'.toJS, <int>[20, 40, 20].jsify());
      case HapticKind.error:
        nav.callMethod('vibrate'.toJS, <int>[40, 30, 40].jsify());
    }
  }
}
