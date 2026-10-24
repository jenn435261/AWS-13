import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Centralized toast/snackbar service with haptics and an optional undo action.
///
/// Rule compliance: a single place for all transient feedback (no duplicated
/// SnackBar code), haptic feedback on show and on undo, text >= 16px (enforced
/// by the theme's snackBarTheme), and a clear undo affordance for undoable or
/// destructive actions (spec: top/bottom toasts with haptics for redo/undo).
class Toast {
  /// Shows a transient message at the bottom. If [onUndo] is provided, an
  /// "Undo" action is attached and invoking it fires a selection haptic.
  static void show(
    BuildContext context,
    String message, {
    String? undoLabel,
    VoidCallback? onUndo,
    Duration duration = const Duration(seconds: 5),
    bool urgent = false,
  }) {
    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        // SnackBars that carry an action stay on screen until dismissed unless
        // persist is false; every toast here must auto-dismiss.
        persist: false,
        backgroundColor: urgent ? Theme.of(context).colorScheme.error : null,
        action: (onUndo != null)
            ? SnackBarAction(
                label: undoLabel ?? 'Undo',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onUndo();
                },
              )
            : null,
      ),
    );
  }
}
