import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../models/role.dart';
import '../../state/app_scope.dart';
import '../../state/settings_controller.dart';
import '../../ui/theme.dart';
import '../deliveries/deliveries_screen.dart';
import '../help/offer_flow.dart';

/// Everything that isn't a main action (Spec section 63), itemized with
/// icons and one line saying its current state.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final l = AppLocalizations.of(context);
    final settings = scope.settings;

    return Scaffold(
      appBar: AppBar(title: Text(l.navMore)),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          settings,
          scope.auth,
          repo.requests,
          repo.offer,
          repo.missions,
          repo.network,
          repo.readiness,
          repo.organizations,
        ]),
        builder: (context, _) {
          final role = scope.auth.role;
          final open = repo.requests.value.where((r) => r.mine && r.isOpen).length;
          final offer = repo.offer.value;
          final network = repo.network.value;
          final package = repo.readiness.value;

          return ListView(
            padding: const EdgeInsets.only(bottom: helpButtonClearance + 16),
            children: [
              _Section(l.sectionActivity),
              _Item(
                icon: Icons.sos_outlined,
                title: l.myRequests,
                subtitle: l.openCount(open),
                onTap: () => context.go('/more/requests'),
              ),
              _Item(
                icon: Icons.volunteer_activism_outlined,
                title: l.mySupplies,
                subtitle: offer == null ? l.notOffering : l.offeringList(l.supplies(offer.kinds)),
                onTap: () => openOfferFlow(context),
              ),
              if (deliveriesVisible(scope))
                _Item(
                  icon: Icons.local_shipping_outlined,
                  title: l.deliveries,
                  subtitle: l.deliveriesSub,
                  onTap: () => context.go('/more/deliveries'),
                ),
              _Section(l.sectionNetwork),
              _Item(
                icon: network.internet ? Icons.cloud_done_outlined : Icons.cloud_off,
                title: l.networkTitle,
                subtitle: '${network.internet ? l.statusOnline : l.statusOffline}  ·  '
                    '${l.lastSyncAgo(l.timeAgo(network.lastSync))}',
                onTap: () => context.go('/more/network'),
              ),
              _Item(
                icon: Icons.download_for_offline_outlined,
                title: l.downloadsTitle,
                subtitle: package.updateAvailable
                    ? l.packageUpdate(package.version)
                    : l.packageUpToDate(l.timeAgo(package.downloadedAt!)),
                onTap: () => context.go('/more/downloads'),
              ),
              _Item(
                icon: Icons.verified_outlined,
                title: l.orgsTitle,
                subtitle: l.orgCount(repo.organizations.value.length),
                onTap: () => context.go('/more/organizations'),
              ),
              _Section(l.sectionSettings),
              _Item(
                icon: Icons.person_outline,
                title: l.account,
                subtitle: scope.auth.isSignedIn
                    ? '${l.signedInAs(scope.auth.me.name)} · ${l.role(role)}'
                    : l.guestMode,
                onTap: () => context.go('/more/account'),
              ),
              _Item(
                icon: Icons.translate,
                title: l.language,
                subtitle: supportedLanguages[settings.language] ?? l.languageSystem,
                onTap: () => context.go('/more/language'),
              ),
              _Item(
                icon: Icons.accessibility_new,
                title: l.display,
                subtitle: l.displaySub((settings.textScale * 100).round()),
                onTap: () => context.go('/more/display'),
              ),
              _Item(
                icon: Icons.lock_outline,
                title: l.privacy,
                subtitle: settings.lockOnOpen ? l.phoneLockOn : l.phoneLockOff,
                onTap: () => context.go('/more/privacy'),
              ),
              if (role.atLeast(Role.manager)) ...[
                _Section(l.sectionManage),
                _Item(
                  icon: Icons.tune,
                  title: l.manage,
                  subtitle: l.manageSub,
                  onTap: () => context.go('/more/manage'),
                ),
                if (role.atLeast(Role.admin))
                  _Item(
                    icon: Icons.admin_panel_settings_outlined,
                    title: l.admin,
                    subtitle: l.adminSub,
                    onTap: () => context.go('/more/admin'),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: c.secondaryContainer,
        foregroundColor: c.onSecondaryContainer,
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
