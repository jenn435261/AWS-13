import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Shared, reusable UI components. Centralized so screens never re-implement
/// the same widget (keeps the app slim and consistent).

/// A skeleton loading placeholder with a subtle shimmer. Shown while data
/// loads so there is always visible feedback (never a blank blocking screen).
class SkeletonBox extends StatefulWidget {
  final double height;
  final double? width;
  final EdgeInsets margin;
  const SkeletonBox({
    super.key,
    this.height = 20,
    this.width,
    this.margin = EdgeInsets.zero,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 0.9).animate(_c),
      child: Container(
        height: widget.height,
        width: widget.width,
        margin: widget.margin,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// A list of [count] skeleton rows for list placeholders.
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 5});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ListView.builder(
        itemCount: count,
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, index) => const SkeletonBox(
          height: 64,
          margin: EdgeInsets.only(bottom: 12),
        ),
      ),
    );
  }
}

/// Text that can be tapped or long-pressed to copy itself to the clipboard,
/// with a trailing copy icon. Used for Resilience IDs, codes, addresses —
/// anything "important info" that should be easy to copy (spec/global rule).
class CopyableText extends StatelessWidget {
  final String value;
  final String? display;
  final String copiedMessage;
  final TextStyle? style;
  final bool monospace;
  const CopyableText({
    super.key,
    required this.value,
    this.display,
    this.copiedMessage = 'Copied to clipboard',
    this.style,
    this.monospace = true,
  });

  @override
  Widget build(BuildContext context) {
    final text = display ?? value;
    Future<void> doCopy() async {
      await Clipboard.setData(ClipboardData(text: value));
      await HapticFeedback.selectionClick();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(copiedMessage)));
      }
    }

    return Semantics(
      label: '$text, double tap to copy',
      button: true,
      child: InkWell(
        onTap: doCopy,
        onLongPress: doCopy,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  text,
                  style: (style ?? const TextStyle(fontSize: 16)).copyWith(
                    fontFamily: monospace ? 'monospace' : null,
                    fontFeatures: const [],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.copy_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// An expandable "Advanced options" disclosure so secondary options never
/// clutter the primary flow (hard UI rule). Collapsed by default.
class AdvancedDisclosure extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;
  const AdvancedDisclosure({
    super.key,
    required this.label,
    required this.children,
    this.icon = Icons.tune_rounded,
    this.initiallyExpanded = false,
  });

  @override
  State<AdvancedDisclosure> createState() => _AdvancedDisclosureState();
}

class _AdvancedDisclosureState extends State<AdvancedDisclosure> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                Icon(widget.icon, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.label,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                Icon(_open
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widget.children,
          ),
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ],
    );
  }
}

/// A single large primary action button (used for the map's central action and
/// step-flow "Send" buttons). Fires a medium haptic on press.
class PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool urgent;
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: 64,
        child: FilledButton.icon(
          onPressed: onPressed == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onPressed!();
                },
          style: FilledButton.styleFrom(
            backgroundColor: urgent ? AppTheme.urgent : scheme.primary,
            foregroundColor: Colors.white,
            textStyle:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          icon: Icon(icon, size: 28),
          label: Text(label),
        ),
      ),
    );
  }
}
