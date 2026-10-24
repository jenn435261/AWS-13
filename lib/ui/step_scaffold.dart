import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';

/// The same frame for every step of every flow: back arrow, close, progress
/// bar, a title, and one large main action at the bottom. Each step is its
/// own route, so the phone's Back gesture and the browser's back and forward
/// buttons move between steps.
class StepScaffold extends StatelessWidget {
  const StepScaffold({
    super.key,
    required this.step,
    required this.total,
    required this.title,
    required this.children,
    required this.actionLabel,
    required this.onAction,
    required this.onClose,
    this.actionIcon = Icons.arrow_forward,
    this.actionColor,
  });

  final int step;
  final int total;
  final String title;
  final List<Widget> children;
  final String actionLabel;
  final IconData actionIcon;

  /// Null disables the main action.
  final VoidCallback? onAction;
  final VoidCallback onClose;
  final Color? actionColor;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.stepOf(step, total)),
        actions: [
          IconButton(
            tooltip: l.close,
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: step / total,
            semanticsLabel: l.stepOf(step, total),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.headlineSmall),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              backgroundColor: actionColor,
            ),
            onPressed: onAction,
            icon: Icon(actionIcon),
            label: Text(actionLabel),
          ),
        ),
      ),
    );
  }
}

/// A large tappable choice: icon, title, optional subtext, and a check when
/// selected. Used for every pick-one and pick-many list.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.multiSelect = false,
    this.iconColors,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onTap;

  /// Background and foreground of the icon circle.
  final (Color, Color)? iconColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final (iconBg, iconFg) =
        iconColors ?? (c.secondaryContainer, c.onSecondaryContainer);
    final trailing = switch ((selected, multiSelect)) {
      (true, true) => Icons.check_box,
      (false, true) => Icons.check_box_outline_blank,
      (true, false) => Icons.check_circle,
      (false, false) => null,
    };

    return Semantics(
      selected: selected,
      checked: multiSelect ? selected : null,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: selected ? c.primaryContainer : null,
        shape: selected
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: c.primary, width: 2),
              )
            : null,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: iconBg,
                  foregroundColor: iconFg,
                  child: Icon(icon, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Icon(trailing, color: selected ? c.primary : c.outline),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
