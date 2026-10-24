import 'package:flutter/material.dart';

/// Text scale at which two side-by-side buttons no longer fit their labels.
const _stackAtTextScale = 1.3;

/// The one or two main actions anchored at the bottom of a detail screen
/// (rule 2). The main one is wider and on the right; the other sits on its
/// left. With large text they stack, the main one at the bottom, so no label
/// is cut off. Draws nothing when there is no [primary] action.
class ActionBar extends StatelessWidget {
  const ActionBar({super.key, required this.primary, this.secondary, this.note});

  final Widget? primary;
  final Widget? secondary;

  /// One line above the buttons, for something to know before tapping.
  final Widget? note;

  @override
  Widget build(BuildContext context) {
    if (primary == null) return const SizedBox.shrink();
    final stacked = MediaQuery.textScalerOf(context).scale(16) / 16 >= _stackAtTextScale;

    final Widget buttons;
    if (secondary == null) {
      buttons = SizedBox(width: double.infinity, child: primary);
    } else if (stacked) {
      buttons = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [secondary!, const SizedBox(height: 8), primary!],
      );
    } else {
      buttons = Row(
        children: [
          Expanded(child: secondary!),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: primary!),
        ],
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (note != null) ...[note!, const SizedBox(height: 8)],
            buttons,
          ],
        ),
      ),
    );
  }
}
