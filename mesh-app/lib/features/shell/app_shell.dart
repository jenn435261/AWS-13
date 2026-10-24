import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../router.dart';
import '../../ui/feedback.dart';
import '../../ui/surfaces.dart';
import 'help_button.dart';

/// A floating frosted bar with the Help button in the middle on phones; a
/// side rail on tablets, desktop and web. Every tab keeps its place when you
/// switch away.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _wideBreakpoint = 720.0;

  void _select(int index) {
    Haptics.tick();
    // Tapping the current tab again goes back to its first screen.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideBreakpoint) {
          return Scaffold(
            body: Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: shell.currentIndex,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: HelpButton(size: 72),
                    ),
                    destinations: [
                      for (final tab in appTabs)
                        NavigationRailDestination(
                          icon: Icon(tab.icon),
                          selectedIcon: Icon(tab.selectedIcon),
                          label: Text(tab.label(l)),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: shell),
              ],
            ),
          );
        }

        // Back from another tab returns to the map before leaving the app.
        return PopScope(
          canPop: shell.currentIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _select(0);
          },
          child: Scaffold(
            // Content runs under the bar, so the map fills the screen. The
            // bar's height reaches screens as bottom padding.
            extendBody: true,
            body: shell,
            bottomNavigationBar: _FloatingBar(
              currentIndex: shell.currentIndex,
              onSelect: _select,
            ),
          ),
        );
      },
    );
  }
}

class _FloatingBar extends StatelessWidget {
  const _FloatingBar({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const _barHeight = 72.0;
  static const _buttonSize = 78.0;

  /// How far the Help button rises above the bar.
  static const _rise = 26.0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          height: _barHeight + _rise,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _barHeight,
                child: Glass(
                  radius: _barHeight / 2,
                  child: Row(
                    children: [
                      for (var i = 0; i < appTabs.length; i++) ...[
                        if (i == 2) const SizedBox(width: _buttonSize + 4),
                        Expanded(
                          child: _TabButton(
                            tab: appTabs[i],
                            label: appTabs[i].label(l),
                            selected: currentIndex == i,
                            onTap: () => onSelect(i),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Positioned(
                top: 0,
                child: HelpButton(size: _buttonSize),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final TabSpec tab;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: selected ? 52 : 40,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? c.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                selected ? tab.selectedIcon : tab.icon,
                size: 22,
                color: selected ? c.onPrimaryContainer : c.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            // Labels sit below the Help button's curve, so a long one
            // ("Contactos") may borrow a little room from the gap beside it.
            LayoutBuilder(
              builder: (context, box) => SizedBox(
                width: box.maxWidth,
                height: 20,
                child: OverflowBox(
                  maxWidth: box.maxWidth + 28,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? c.onSurface : c.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: -0.3,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
