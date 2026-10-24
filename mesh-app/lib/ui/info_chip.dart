import 'package:flutter/material.dart';

import 'theme.dart';

/// A small label with an optional icon that tells a fact, such as "Verified
/// organization" or "Map offline". It is not a button.
///  * [strong]: in the brand color, for a fact worth trusting.
///  * [onMap]: on the solid panel color with a thin outline, so it reads over
///    the street map.
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.label,
    this.icon,
    this.strong = false,
    this.onMap = false,
    this.maxLines,
  });

  final String label;
  final IconData? icon;
  final bool strong;
  final bool onMap;

  /// Null lets long labels wrap; 1 cuts them with an ellipsis.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final panel = AppColors.of(context);
    final (bg, fg) = strong
        ? (c.primaryContainer, c.onPrimaryContainer)
        : onMap
            ? (panel.glass, c.onSurfaceVariant)
            : (c.surfaceContainerHighest, c.onSurfaceVariant);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: onMap ? Border.all(color: panel.glassBorder, width: panel.borderWidth) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: maxLines,
                overflow: maxLines == null ? null : TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
