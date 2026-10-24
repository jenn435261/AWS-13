import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/contacts/contacts_screen.dart';
import 'features/contacts/my_qr_screen.dart';
import 'features/contacts/scan_screen.dart';
import 'features/deliveries/deliveries_screen.dart';
import 'features/deliveries/mission_screen.dart';
import 'features/help/offer_flow.dart';
import 'features/help/request_flow.dart';
import 'features/manage/manage_screen.dart';
import 'features/map/map_screen.dart';
import 'features/messages/chat_screen.dart';
import 'features/messages/messages_screen.dart';
import 'features/more/account_screen.dart';
import 'features/more/display_screen.dart';
import 'features/more/downloads_screen.dart';
import 'features/more/language_screen.dart';
import 'features/more/more_screen.dart';
import 'features/more/network_screen.dart';
import 'features/more/organizations_screen.dart';
import 'features/more/privacy_screen.dart';
import 'features/nodes/nodes_screen.dart';
import 'features/requests/request_screen.dart';
import 'features/requests/requests_screen.dart';
import 'features/requests/responder_card.dart';
import 'features/shell/app_shell.dart';
import 'features/shell/deferred_screen.dart';
import 'l10n/labels.dart';
import 'models/role.dart';
import 'state/auth_controller.dart';
import 'state/drafts.dart';

// Deferred: on web, admin code is a separate download that only admins fetch.
import 'features/admin/admin_screen.dart' deferred as admin;

/// A bottom-bar tab (Spec section 59). The Help button sits in the middle,
/// between tabs 2 and 3.
class TabSpec {
  const TabSpec(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations l) label;
}

final appTabs = <TabSpec>[
  TabSpec(Icons.map_outlined, Icons.map, (l) => l.navMap),
  TabSpec(Icons.chat_bubble_outline, Icons.chat_bubble, (l) => l.navMessages),
  TabSpec(Icons.people_outline, Icons.people, (l) => l.navContacts),
  TabSpec(Icons.menu, Icons.menu_open, (l) => l.navMore),
];

String requestPath(String id) => '/more/requests/$id';
String missionPath(String id) => '/more/deliveries/$id';

final _rootKey = GlobalKey<NavigatorState>();

Page<void> _tab(Widget child) => NoTransitionPage(child: child);

GoRoute _route(String path, Widget Function(GoRouterState s) build,
        {List<RouteBase> routes = const [], bool fullScreen = false}) =>
    GoRoute(
      path: path,
      parentNavigatorKey: fullScreen ? _rootKey : null,
      builder: (_, state) => build(state),
      routes: routes,
    );

GoRouter buildRouter({
  required AuthController auth,
  required RequestDraft requestDraft,
  required OfferDraft offerDraft,
}) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/map',
    refreshListenable: auth,
    redirect: (context, state) {
      final path = state.uri.path;

      // Keep users out of screens above their role. This is a UX guard only;
      // the backend must enforce the same rules.
      if (path.startsWith('/more/manage') && !auth.role.atLeast(Role.manager)) {
        return '/more';
      }
      if (path.startsWith('/more/admin') && !auth.role.atLeast(Role.admin)) {
        return '/more';
      }

      // Later steps of a flow need the earlier answers.
      if (path.startsWith('/help/') && requestDraft.kind == null) return '/help';
      if (path.startsWith('/offer/') && offerDraft.kinds.isEmpty) {
        return '/offer';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/map'),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(path: '/map', pageBuilder: (_, _) => _tab(const MapScreen())),
            ],
          ),
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: '/messages',
                pageBuilder: (_, _) => _tab(const MessagesScreen()),
                routes: [
                  _route(':channel',
                      (s) => ChatScreen(channelId: s.pathParameters['channel']!)),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: '/contacts',
                pageBuilder: (_, _) => _tab(const ContactsScreen()),
                routes: [
                  _route('qr', (_) => const MyQrScreen(), fullScreen: true),
                  _route('scan', (_) => const ScanScreen(), fullScreen: true),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: '/more',
                pageBuilder: (_, _) => _tab(const MoreScreen()),
                routes: [
                  _route('requests', (_) => const RequestsScreen(), routes: [
                    _route(':id', (s) => RequestScreen(id: s.pathParameters['id']!),
                        routes: [
                          _route('card',
                              (s) => ResponderCard(id: s.pathParameters['id']!),
                              fullScreen: true),
                        ]),
                  ]),
                  _route('deliveries', (_) => const DeliveriesScreen(), routes: [
                    _route(':id', (s) => MissionScreen(id: s.pathParameters['id']!),
                        routes: [
                          _route('code',
                              (s) => PackageCodeScreen(id: s.pathParameters['id']!),
                              fullScreen: true),
                          _route('scan',
                              (s) => ScanScreen(missionId: s.pathParameters['id']),
                              fullScreen: true),
                        ]),
                  ]),
                  _route('network', (_) => const NetworkScreen(), routes: [
                    _route('radios', (_) => const NodesScreen()),
                  ]),
                  _route('downloads', (_) => const DownloadsScreen()),
                  _route('organizations', (_) => const OrganizationsScreen()),
                  _route('account', (_) => const AccountScreen()),
                  _route('language', (_) => const LanguageScreen()),
                  _route('display', (_) => const DisplayScreen()),
                  _route('privacy', (_) => const PrivacyScreen()),
                  _route('manage', (_) => const ManageScreen()),
                  _route(
                    'admin',
                    (_) => DeferredScreen(
                      loader: () => admin.loadLibrary(),
                      builder: (context) => admin.AdminScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Flows cover the whole screen. Each step is its own route, so Back
      // always goes to the previous step.
      GoRoute(
        path: '/help',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const HelpKindStep(),
        routes: [
          GoRoute(path: 'details', builder: (_, _) => const HelpDetailsStep()),
        ],
      ),
      GoRoute(
        path: '/offer',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const OfferKindsStep(),
        routes: [
          GoRoute(path: 'details', builder: (_, _) => const OfferDetailsStep()),
        ],
      ),
    ],
  );
}
