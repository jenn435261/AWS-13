import 'package:flutter/material.dart';

/// A screen's one or two main actions, anchored at the bottom. Use it as a
/// Scaffold's `bottomNavigationBar`: on a tab it sits just above the floating
/// bar, whose height reaches it as bottom padding.
class BottomActions extends StatelessWidget {
  const BottomActions({super.key, required this.main, this.secondary = const []});

  /// Usually a [MainButton].
  final Widget main;

  /// Smaller actions under the main one, such as an [OutlinedButton].
  final List<Widget> secondary;

  /// For [secondary] buttons: full width and easy to hit.
  static const secondaryStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size.fromHeight(52)),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            main,
            for (final action in secondary) ...[
              const SizedBox(height: 8),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
