import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../router.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/hold_button.dart';
import '../../ui/surfaces.dart';
import '../../ui/visuals.dart';
import '../help/offer_flow.dart';
import '../help/request_flow.dart';

/// The red Help button in the middle of the bottom bar.
///  * Tap: choose "I need help" or "I can help".
///  * Hold 2 seconds: send an SOS with the location, no questions. A white
///    ring fills around the edge while held.
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, this.size = 78, this.sosOnly = false});

  final double size;

  /// On the lock screen a tap can't open the menu, so it only explains.
  final bool sosOnly;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return HoldButton(
      semanticsLabel: l.helpButtonSemantics,
      semanticsHint: l.helpButtonHint,
      onTap:
          sosOnly
              ? () => AppScope.of(
                context,
              ).feedback.toast(l.keepHolding, icon: Icons.touch_app_outlined)
              : () => showHelpMenu(context),
      onHeld: () => sendSos(context),
      // Pressing shrinks the button a little and a white ring fills around
      // its edge, so you can feel and see the hold working.
      builder:
          (context, progress) => Transform.scale(
            scale: 1 - 0.05 * Curves.easeOut.transform(min(progress * 3, 1)),
            child: CustomPaint(
              foregroundPainter: _HoldRing(progress),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sosRed,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: softShadow(context, lift: 0.6),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sos, color: Colors.white, size: size * 0.36),
                    // A long word ("Tulong", "Ayuda") stays whole at 150% text.
                    // Scaling the paint keeps the style at 16 px or more.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l.helpButton,
                          softWrap: false,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

class _HoldRing extends CustomPainter {
  _HoldRing(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rect = (Offset.zero & size).deflate(7);
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_HoldRing old) => old.progress != progress;
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
    run:
        () async =>
            id = (await scope.repository.sendSos(from: scope.auth.me)).id,
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
    isScrollControlled: true,
    builder:
        (sheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                  child: Text(
                    l.helpMenuTitle,
                    style: Theme.of(sheet).textTheme.headlineSmall,
                  ),
                ),
                _BigChoice(
                  icon: Icons.sos,
                  color: sosRed,
                  title: l.needHelp,
                  subtitle: l.needHelpSub,
                  onTap: () {
                    Navigator.pop(sheet);
                    openRequestFlow(context);
                  },
                ),
                const SizedBox(height: 12),
                _BigChoice(
                  icon: Icons.volunteer_activism,
                  title: l.canHelp,
                  subtitle: l.canHelpSub,
                  onTap: () {
                    Navigator.pop(sheet);
                    openOfferFlow(context);
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
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
                ),
              ],
            ),
          ),
        ),
  );
}

/// A large card for the two choices behind the Help button. Asking for help
/// is solid red; offering help is a plain card, so the urgent choice leads.
class _BigChoice extends StatelessWidget {
  const _BigChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Fill color with white text; null for a plain card.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final filled = color != null;
    final ink = filled ? Colors.white : c.onSurface;

    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      shape:
          filled
              ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))
              : null,
      child: InkWell(
        onTap: () {
          Haptics.tick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              filled
                  ? Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(icon, color: Colors.white, size: 30),
                  )
                  : IconTile(icon: icon, color: c.primary, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: filled ? Colors.white : c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                color: filled ? Colors.white : c.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
