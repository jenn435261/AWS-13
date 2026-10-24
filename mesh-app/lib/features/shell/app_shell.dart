import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../router.dart';
import '../../ui/feedback.dart';
import '../../ui/surfaces.dart';
import 'help_button.dart';

/// A floating frosted bar with the Help button in the middle on phones; a
/// side rail on tablets, desktop and web. Every tab keeps its place when you
/// switch away, and on a tab's first screen you can swipe to the next tab.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell, required this.state});

  final StatefulNavigationShell shell;
  final GoRouterState state;

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

        final index = shell.currentIndex;
        // Back from another tab returns to the map before leaving the app.
        return PopScope(
          canPop: index == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _select(0);
          },
          child: Scaffold(
            // Content runs under the bar, so the map fills the screen. The
            // bar's height reaches screens as bottom padding.
            extendBody: true,
            body: TabSwipe(
              // The map pans with a sideways drag, so it never swipes away.
              enabled: index != 0 && state.uri.path == appTabs[index].path,
              onSwipe: (step) {
                final next = index + step;
                if (next >= 0 && next < appTabs.length) _select(next);
              },
              child: shell,
            ),
            bottomNavigationBar: _FloatingBar(
              currentIndex: index,
              onSelect: _select,
            ),
          ),
        );
      },
    );
  }
}

/// Turns a sideways swipe into a step to the next (+1) or previous (-1) tab.
/// Lists that page sideways themselves (Direct, Community, Mission) keep the
/// swipe until their last page; a swipe past it moves to the next tab.
class TabSwipe extends StatefulWidget {
  const TabSwipe({
    super.key,
    required this.enabled,
    required this.onSwipe,
    required this.child,
  });

  final bool enabled;
  final ValueChanged<int> onSwipe;
  final Widget child;

  /// How far a finger travels, or pulls past a list's last page, to count.
  static const distance = 56.0;

  /// A quick flick counts even when short, in logical pixels per second.
  static const speed = 600.0;

  @override
  State<TabSwipe> createState() => _TabSwipeState();
}

class _TabSwipeState extends State<TabSwipe> {
  double _drag = 0;
  double _pastEdge = 0;

  void _dragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final moved = _drag.abs() >= TabSwipe.distance ? _drag : 0.0;
    final flung = velocity.abs() >= TabSwipe.speed ? velocity : 0.0;
    final direction = moved != 0 ? moved : flung;
    _drag = 0;
    // The finger moving left brings in the tab on the right.
    if (direction != 0) widget.onSwipe(direction < 0 ? 1 : -1);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.horizontal) return false;
    switch (n) {
      case ScrollStartNotification():
        _pastEdge = 0;
      case OverscrollNotification(:final dragDetails?, :final overscroll):
        // Clamping lists (Android) report the pull past their edge.
        if (dragDetails.primaryDelta != null) _pastEdge += overscroll;
      case ScrollUpdateNotification(:final metrics, dragDetails: _?)
          when metrics.outOfRange:
        // Bouncing lists (iOS) move past their edge instead.
        _pastEdge = metrics.pixels < metrics.minScrollExtent
            ? metrics.pixels - metrics.minScrollExtent
            : metrics.pixels - metrics.maxScrollExtent;
      case ScrollEndNotification():
        final past = _pastEdge;
        _pastEdge = 0;
        if (past.abs() >= TabSwipe.distance) widget.onSwipe(past > 0 ? 1 : -1);
      default:
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => _drag = 0,
        onHorizontalDragUpdate: (d) => _drag += d.primaryDelta ?? 0,
        onHorizontalDragEnd: _dragEnd,
        child: widget.child,
      ),
    );
  }
}

class _FloatingBar extends StatelessWidget {
  const _FloatingBar({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const _barHeight = 72.0;
  static const _buttonSize = 78.0;
  static const _gap = _buttonSize + 4;

  /// How far the Help button rises above the bar.
  static const _rise = 26.0;

  /// How far a label next to the Help button may reach into the gap under
  /// it: the button is round, so its lower corners leave room.
  static const _borrow = 14.0;

  /// Above this text size the labels stay in the screen reader only, and the
  /// icons speak for themselves.
  static const _maxLabelScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final labelStyle = theme.textTheme.labelLarge!.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      height: 1.1,
    );
    final labels = [for (final tab in appTabs) tab.label(l)];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          height: _barHeight + _rise,
          child: LayoutBuilder(
            builder: (context, box) {
              final tabWidth = (box.maxWidth - _gap) / appTabs.length;
              // Each label is measured as it will be drawn. If any one would
              // run into its neighbor, none are drawn, so the bar stays even.
              double room(int i) => tabWidth - 4 + (i == 1 || i == 2 ? _borrow : 0);
              final widths = [
                for (final label in labels) _measure(label, labelStyle, scaler),
              ];
              final fontSize = labelStyle.fontSize!;
              final showLabels = scaler.scale(fontSize) / fontSize <= _maxLabelScale &&
                  [for (var i = 0; i < labels.length; i++) widths[i] <= room(i)]
                      .every((fits) => fits);

              return Stack(
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
                            if (i == 2) const SizedBox(width: _gap),
                            Expanded(
                              child: _TabButton(
                                index: i,
                                tab: appTabs[i],
                                label: labels[i],
                                labelWidth: showLabels ? widths[i] : null,
                                // Labels beside the Help button lean into
                                // the gap under it when they need the room.
                                shift: !showLabels
                                    ? 0
                                    : switch (i) {
                                        1 => ((widths[i] - tabWidth + 4) / 2).clamp(0.0, _borrow),
                                        2 => -((widths[i] - tabWidth + 4) / 2).clamp(0.0, _borrow),
                                        _ => 0,
                                      },
                                labelStyle: labelStyle,
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
              );
            },
          ),
        ),
      ),
    );
  }

  static double _measure(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: scaler,
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width.ceilToDouble();
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.index,
    required this.tab,
    required this.label,
    required this.labelWidth,
    required this.shift,
    required this.labelStyle,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final TabSpec tab;
  final String label;

  /// The label's measured width, or null when labels are hidden.
  final double? labelWidth;

  /// How far to move the label sideways from the middle of the tab.
  final double shift;
  final TextStyle labelStyle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final width = labelWidth;

    final icon = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: selected ? 52 : 40,
      height: width == null ? 36 : 30,
      decoration: BoxDecoration(
        color: selected ? c.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(
        selected ? tab.selectedIcon : tab.icon,
        size: width == null ? 26 : 22,
        color: selected ? c.onPrimaryContainer : c.onSurfaceVariant,
      ),
    );

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: width == null
            // Without a label, holding the icon still names the tab.
            ? Tooltip(message: label, child: Center(child: icon))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(height: 3),
                  Transform.translate(
                    offset: Offset(shift, 0),
                    child: OverflowBox(
                      minWidth: 0,
                      maxWidth: width,
                      fit: OverflowBoxFit.deferToChild,
                      child: Text(
                        label,
                        key: ValueKey('tab-label-$index'),
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: labelStyle.copyWith(
                          color: selected ? c.onSurface : c.onSurfaceVariant,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
