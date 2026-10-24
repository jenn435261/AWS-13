import 'package:flutter/material.dart';

import '../../l10n/labels.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/theme.dart';
import '../shell/help_button.dart';

/// Shown while the app is locked. SOS still works, like the emergency call
/// button on a phone's lock screen.
class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  Future<void> _unlock(BuildContext context) async {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    Haptics.tick();
    if (!await scope.lock.unlock(l.unlockReason)) {
      scope.feedback.toast(l.unlockFailed, icon: Icons.error_outline, strong: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lock = AppScope.of(context).lock;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock, size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    l.lockedTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(l.lockedSub, textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                    ),
                    onPressed: () => _unlock(context),
                    icon: const Icon(Icons.fingerprint),
                    label: Text(l.unlock),
                  ),
                  if (!lock.deviceLockAvailable) ...[
                    const SizedBox(height: 12),
                    Text(
                      l.unlockWebNote,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 48),
                  const Center(child: HelpButton(size: 96, sosOnly: true)),
                  const SizedBox(height: 12),
                  Text(
                    l.holdForSos,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: helpButtonClearance),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
