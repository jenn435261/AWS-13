import 'package:flutter/services.dart';

import 'haptic_kind.dart';

/// Native haptics via Flutter's platform channel. On a device without a
/// vibrator the platform simply does nothing.
class PlatformHaptics {
  const PlatformHaptics();

  void vibrate(HapticKind kind) {
    switch (kind) {
      case HapticKind.selection:
        HapticFeedback.selectionClick();
      case HapticKind.confirm:
        HapticFeedback.mediumImpact();
      case HapticKind.success:
        HapticFeedback.heavyImpact();
      case HapticKind.error:
        HapticFeedback.vibrate();
    }
  }
}
