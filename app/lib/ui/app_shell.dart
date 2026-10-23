import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../l10n/strings.dart';
import 'screens/contacts_screen.dart';
import 'screens/deliveries_screen.dart';
import 'screens/map_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/more_screen.dart';

/// The root scaffold: map-first with a bottom NavigationBar (Map / Messages /
/// Contacts / More, plus a conditional Deliveries tab per spec §64). Switching
/// tabs preserves each tab's own navigation stack so back always works.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final showDeliveries = ref.watch(showDeliveriesProvider);

    // Tab definitions; Deliveries is inserted only when relevant.
    final tabs = <_Tab>[
      _Tab(const MapScreen(), Icons.map_rounded, l.t('nav_map')),
      _Tab(const MessagesScreen(), Icons.forum_rounded, l.t('nav_messages')),
      _Tab(const ContactsScreen(), Icons.contacts_rounded, l.t('nav_contacts')),
      if (showDeliveries)
        _Tab(const DeliveriesScreen(), Icons.local_shipping_rounded,
            l.t('nav_deliveries')),
      _Tab(const MoreScreen(), Icons.menu_rounded, l.t('nav_more')),
    ];
    final safeIndex = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      // IndexedStack keeps each tab alive with its own Navigator state.
      body: IndexedStack(
        index: safeIndex,
        children: [
          for (final t in tabs)
            Navigator(
              onGenerateRoute: (settings) =>
                  MaterialPageRoute(builder: (_) => t.screen),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _Tab {
  final Widget screen;
  final IconData icon;
  final String label;
  const _Tab(this.screen, this.icon, this.label);
}
