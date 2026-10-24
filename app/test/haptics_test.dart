import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/core/haptics/haptics.dart';

void main() {
  group('Haptics gating', () {
    test('no-ops when the toggle is OFF (never touches the platform)', () {
      final fired = <HapticKind>[];
      final haptics = Haptics(sink: fired.add);

      haptics.fire(HapticKind.selection, enabled: false);
      haptics.fire(HapticKind.confirm, enabled: false);
      haptics.fire(HapticKind.success, enabled: false);
      haptics.fire(HapticKind.error, enabled: false);

      expect(fired, isEmpty);
    });

    test('calls the platform sink when the toggle is ON', () {
      final fired = <HapticKind>[];
      final haptics = Haptics(sink: fired.add);

      haptics.fire(HapticKind.selection, enabled: true);
      haptics.fire(HapticKind.confirm, enabled: true);
      haptics.fire(HapticKind.success, enabled: true);
      haptics.fire(HapticKind.error, enabled: true);

      expect(fired, <HapticKind>[
        HapticKind.selection,
        HapticKind.confirm,
        HapticKind.success,
        HapticKind.error,
      ]);
    });

    test('a throwing sink never propagates (best-effort feedback)', () {
      final haptics = Haptics(sink: (_) => throw StateError('no vibrator'));
      // Must not throw even when the platform call fails.
      expect(() => haptics.fire(HapticKind.confirm, enabled: true),
          returnsNormally);
    });
  });
}
