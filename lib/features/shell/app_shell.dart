import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../router.dart';
import '../../ui/feedback.dart';
import 'help_button.dart';

/// Bottom bar with the Help button in the middle on phones; a side rail on
/// tablets, desktop and web. Every tab keeps its place when you switch away.
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
                      padding: EdgeInsets.symmetric(vertical: 12),
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
            body: shell,
            floatingActionButton: const HelpButton(),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            bottomNavigationBar: BottomAppBar(
              height: 84,
              padding: EdgeInsets.zero,
              shape: const CircularNotchedRectangle(),
              notchMargin: 6,
              child: Row(
                children: [
                  for (var i = 0; i < appTabs.length; i++) ...[
                    if (i == 2) const SizedBox(width: 88),
                    Expanded(
                      child: _TabButton(
                        tab: appTabs[i],
                        label: appTabs[i].label(l),
                        selected: shell.currentIndex == i,
                        onTap: () => _select(i),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
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
        containedInkWell: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? c.secondaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                selected ? tab.selectedIcon : tab.icon,
                color: selected ? c.onSecondaryContainer : c.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? c.onSurface : c.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
