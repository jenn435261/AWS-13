import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's three kinds of vibration. Everything uses these, so the same
/// action always feels the same.
abstract final class Haptics {
  /// Choices, tab changes, hold-progress ticks.
  static void tick() => HapticFeedback.selectionClick();

  /// Something was sent or saved.
  static void success() => HapticFeedback.mediumImpact();

  /// SOS, erase, warnings.
  static void strong() => HapticFeedback.heavyImpact();
}

/// Toasts for the whole app, so every screen gives the same feedback.
///  * Bottom toast: the result of the user's own action, with undo or redo.
///  * Top toast: news from the network, such as a new request nearby.
class AppFeedback {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  Timer? _bannerTimer;

  void toast(
    String message, {
    IconData icon = Icons.check_circle_outline,
    String? actionLabel,
    VoidCallback? onAction,
    bool strong = false,
  }) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    strong ? Haptics.strong() : Haptics.success();
    final colors = Theme.of(messenger.context).colorScheme;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: Duration(seconds: onAction == null ? 3 : 6),
          content: Row(
            children: [
              Icon(icon, color: colors.onInverseSurface),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          action: onAction == null
              ? null
              : SnackBarAction(
                  label: actionLabel!,
                  onPressed: () {
                    Haptics.tick();
                    onAction();
                  },
                ),
        ),
      );
  }

  /// Runs [run], then shows [message] with Undo. Undo runs [revert] and
  /// offers Redo, which starts over.
  Future<void> undoable({
    required String message,
    required String undoneMessage,
    required String undoLabel,
    required String redoLabel,
    required Future<void> Function() run,
    required Future<void> Function() revert,
    IconData icon = Icons.check_circle_outline,
  }) async {
    await run();
    toast(
      message,
      icon: icon,
      actionLabel: undoLabel,
      onAction: () async {
        await revert();
        toast(
          undoneMessage,
          icon: Icons.undo,
          actionLabel: redoLabel,
          onAction: () => undoable(
            message: message,
            undoneMessage: undoneMessage,
            undoLabel: undoLabel,
            redoLabel: redoLabel,
            run: run,
            revert: revert,
            icon: icon,
          ),
        );
      },
    );
  }

  void alert(
    String message, {
    required String dismissLabel,
    IconData icon = Icons.notifications_active_outlined,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    Haptics.success();
    _bannerTimer?.cancel();

    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          leading: Icon(icon),
          content: Semantics(liveRegion: true, child: Text(message)),
          actions: [
            if (onAction != null)
              TextButton(
                onPressed: () {
                  messenger.hideCurrentMaterialBanner();
                  Haptics.tick();
                  onAction();
                },
                child: Text(actionLabel!),
              ),
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: Text(dismissLabel),
            ),
          ],
        ),
      );
    _bannerTimer = Timer(
      const Duration(seconds: 6),
      () => messengerKey.currentState?.hideCurrentMaterialBanner(),
    );
  }

  void dispose() => _bannerTimer?.cancel();
}
