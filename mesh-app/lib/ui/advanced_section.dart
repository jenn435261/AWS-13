import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import 'feedback.dart';

/// Detail most people never need, such as radio hops or signatures, folded
/// away under "Advanced" with one line saying what is inside (rule 4).
/// Closed until tapped.
class AdvancedSection extends StatelessWidget {
  const AdvancedSection({
    super.key,
    required this.subtitle,
    required this.children,
    this.title,
    this.icon = Icons.tune,
  });

  /// What is inside, in a few words.
  final String subtitle;
  final List<Widget> children;

  /// Defaults to "Advanced".
  final String? title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      expandedAlignment: Alignment.centerLeft,
      // No lines above and below when open; the list keeps its own rhythm.
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Icon(icon, color: c.onSurfaceVariant),
      title: Text(title ?? l.lookAdvanced),
      subtitle: Text(subtitle),
      onExpansionChanged: (_) => Haptics.tick(),
      children: children,
    );
  }
}
