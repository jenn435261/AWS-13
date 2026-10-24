import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import 'surfaces.dart';

/// The same frame for every step of every flow: back arrow, close, progress
/// segments, a title, and one large main action at the bottom. Each step is
/// its own route, so the phone's Back gesture and the browser's back and
/// forward buttons move between steps.
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

  /// A color for the main action instead of the brand color.
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
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10),
          child: Semantics(
            label: l.stepOf(step, total),
            child: _Segments(step: step, total: total),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(title, style: theme.textTheme.headlineMedium),
              ),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: MainButton(
            label: actionLabel,
            icon: actionIcon,
            onPressed: onAction,
            color: actionColor,
          ),
        ),
      ),
    );
  }
}

/// One bar per step; finished and current steps fill with the brand color.
class _Segments extends StatelessWidget {
  const _Segments({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i < step ? c.primary : c.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        ],
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
    this.hue,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onTap;

  /// The choice's own color, for its icon tile. Defaults to the brand color.
  final Color? hue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
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
        color: selected ? c.primaryContainer.withValues(alpha: 0.55) : null,
        shape: selected
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: c.primary, width: 2),
              )
            : null,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                IconTile(icon: icon, color: hue ?? c.primary, solid: selected),
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
                ] else
                  Icon(Icons.chevron_right, color: c.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
