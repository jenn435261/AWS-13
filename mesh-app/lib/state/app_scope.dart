import 'package:flutter/material.dart';

import '../data/mesh_repository.dart';
import '../l10n/labels.dart';
import '../ui/feedback.dart';
import 'auth_controller.dart';
import 'drafts.dart';
import 'lock_controller.dart';
import 'settings_controller.dart';

/// Hands the app's controllers to any widget below it, without a
/// state-management package. `AppScope.of(context).repository`
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.auth,
    required this.repository,
    required this.settings,
    required this.lock,
    required this.feedback,
    required this.requestDraft,
    required this.offerDraft,
    required super.child,
  });

  final AuthController auth;
  final MeshRepository repository;
  final SettingsController settings;
  final LockController lock;
  final AppFeedback feedback;
  final RequestDraft requestDraft;
  final OfferDraft offerDraft;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget.');
    return scope!;
  }

  /// Runs [run] and shows [message] with Undo; Undo runs [revert] and shows
  /// [undone] with Redo. Every reversible action in the app goes through here.
  Future<void> undoable(
    BuildContext context, {
    required String message,
    required String undone,
    required Future<void> Function() run,
    required Future<void> Function() revert,
    IconData icon = Icons.check_circle_outline,
  }) {
    final l = AppLocalizations.of(context);
    return feedback.undoable(
      message: message,
      undoneMessage: undone,
      undoLabel: l.undo,
      redoLabel: l.redo,
      run: run,
      revert: revert,
      icon: icon,
    );
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      auth != oldWidget.auth ||
      repository != oldWidget.repository ||
      settings != oldWidget.settings ||
      lock != oldWidget.lock;
}
