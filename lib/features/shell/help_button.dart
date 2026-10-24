import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../router.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/hold_button.dart';
import '../../ui/step_scaffold.dart';
import '../../ui/visuals.dart';
import '../help/offer_flow.dart';
import '../help/request_flow.dart';

/// The red Help button in the middle of the bottom bar.
///  * Tap: choose "I need help" or "I can help".
///  * Hold 2 seconds: send an SOS with the location, no questions.
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, this.size = 76, this.sosOnly = false});

  final double size;

  /// On the lock screen a tap can't open the menu, so it only explains.
  final bool sosOnly;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;

    return HoldButton(
      semanticsLabel: l.helpButtonSemantics,
      semanticsHint: l.helpButtonHint,
      onTap: sosOnly
          ? () => AppScope.of(context).feedback.toast(
                l.keepHolding,
                icon: Icons.touch_app_outlined,
              )
          : () => showHelpMenu(context),
      onHeld: () => sendSos(context),
      builder: (context, progress) => SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: size,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 5,
                color: sosRed,
                backgroundColor: c.surface,
              ),
            ),
            Material(
              color: sosRed,
              shape: const CircleBorder(),
              elevation: 3 + progress * 6,
              child: SizedBox.square(
                dimension: size - 12,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sos, color: Colors.white, size: 28),
                    Text(
                      l.helpButton,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sends an SOS and shows its progress, with undo in case it was a mistake.
Future<void> sendSos(BuildContext context) async {
  final scope = AppScope.of(context);
  final l = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  String? id;

  await scope.undoable(
    context,
    message: l.sosSent,
    undone: l.requestCancelled,
    icon: Icons.sos,
    run: () async => id = (await scope.repository.sendSos(from: scope.auth.me)).id,
    revert: () => scope.repository.cancelRequest(id!),
  );
  if (id != null && !scope.lock.locked) router.go(requestPath(id!));
}

Future<void> showHelpMenu(BuildContext context) {
  Haptics.tick();
  final l = AppLocalizations.of(context);
  final c = Theme.of(context).colorScheme;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.helpMenuTitle,
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ChoiceTile(
              icon: Icons.sos,
              iconColors: (sosRed, Colors.white),
              title: l.needHelp,
              subtitle: l.needHelpSub,
              onTap: () {
                Navigator.pop(sheet);
                openRequestFlow(context);
              },
            ),
            const SizedBox(height: 12),
            ChoiceTile(
              icon: Icons.volunteer_activism,
              iconColors: (c.primaryContainer, c.onPrimaryContainer),
              title: l.canHelp,
              subtitle: l.canHelpSub,
              onTap: () {
                Navigator.pop(sheet);
                openOfferFlow(context);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.touch_app_outlined, color: c.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.sosTip,
                    style: TextStyle(color: c.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
