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
import 'features/sos/emergency_contacts_screen.dart';
import 'features/sos/no_network_sos_screen.dart';
import 'l10n/labels.dart';
import 'models/role.dart';
import 'state/auth_controller.dart';
import 'state/drafts.dart';

// Deferred: on web, admin code is a separate download that only admins fetch.
import 'features/admin/admin_screen.dart' deferred as admin;

/// A bottom-bar tab (Spec section 59). The Help button sits in the middle,
/// between tabs 2 and 3.
class TabSpec {
  const TabSpec(this.icon, this.selectedIcon, this.label, this.path);

  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations l) label;

  /// The tab's first screen.
  final String path;
}

final appTabs = <TabSpec>[
  TabSpec(Icons.map_outlined, Icons.map, (l) => l.navMap, '/map'),
  TabSpec(Icons.chat_bubble_outline, Icons.chat_bubble, (l) => l.navMessages, '/messages'),
  TabSpec(Icons.people_outline, Icons.people, (l) => l.navContacts, '/contacts'),
  TabSpec(Icons.menu, Icons.menu_open, (l) => l.navMore, '/more'),
];

// Screens that other tabs open sit on the root navigator, above the tabs.
// Open them with `context.push`, so Back returns to where the person was.
String requestPath(String id) => '/more/requests/$id';
String missionPath(String id) => '/more/deliveries/$id';
String chatPath(String channelId) => '/messages/$channelId';
const newMessagePath = '/messages/new';
const networkPath = '/more/network';
const downloadsPath = '/more/downloads';
const deliveriesPath = '/more/deliveries';
const emergencyContactsPath = '/more/emergency-contacts';

/// Adds an emergency contact, or edits the one at [index].
String emergencyContactFormPath({int? index}) =>
    index == null ? '/emergency-contact' : '/emergency-contact?index=$index';

/// The step shown after an SOS that reached no network.
String sosNoNetworkPath(String requestId) => '/sos/$requestId';

/// Leaves a flow that starts at [root] (such as `/help`) by popping its
/// steps, so the person is back exactly where they opened it. A flow opened
/// from a link has nothing under it, so it goes to [fallback] instead.
void leaveFlow(GoRouter router, String root, {String fallback = '/map'}) {
  bool inFlow() {
    final path = router.state.uri.path;
    return path == root || path.startsWith('$root/');
  }

  while (inFlow() && router.canPop()) {
    router.pop();
  }
  if (inFlow()) router.go(fallback);
}

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
        builder: (context, state, shell) => AppShell(shell: shell, state: state),
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
                  // Before ':channel', so "new" is never read as a channel.
                  _route('new', (_) => const NewMessageScreen(), fullScreen: true),
                  _route(':channel',
                      (s) => ChatScreen(channelId: s.pathParameters['channel']!),
                      fullScreen: true),
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
                        fullScreen: true,
                        routes: [
                          _route('card',
                              (s) => ResponderCard(id: s.pathParameters['id']!),
                              fullScreen: true),
                        ]),
                  ]),
                  _route('deliveries', (_) => const DeliveriesScreen(),
                      fullScreen: true,
                      routes: [
                        _route(':id', (s) => MissionScreen(id: s.pathParameters['id']!),
                            fullScreen: true,
                            routes: [
                              _route('code',
                                  (s) => PackageCodeScreen(id: s.pathParameters['id']!),
                                  fullScreen: true),
                              _route('scan',
                                  (s) => ScanScreen(missionId: s.pathParameters['id']),
                                  fullScreen: true),
                            ]),
                      ]),
                  _route('network', (_) => const NetworkScreen(),
                      fullScreen: true,
                      routes: [
                        _route('radios', (_) => const NodesScreen(), fullScreen: true),
                      ]),
                  _route('downloads', (_) => const DownloadsScreen(), fullScreen: true),
                  _route('organizations', (_) => const OrganizationsScreen()),
                  _route('emergency-contacts', (_) => const EmergencyContactsScreen()),
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
      GoRoute(
        path: '/sos/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => NoNetworkSosScreen(requestId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/emergency-contact',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => EmergencyContactForm(
          index: int.tryParse(s.uri.queryParameters['index'] ?? ''),
        ),
      ),
    ],
  );
}
