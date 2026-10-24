import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../models/role.dart';
import '../../router.dart';
import '../../state/app_scope.dart';
import '../../state/settings_controller.dart';
import '../../ui/surfaces.dart';
import '../../ui/theme.dart';
import '../../ui/visuals.dart';
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
            padding: EdgeInsets.only(bottom: bottomClearance(context)),
            children: [
              GroupHeader(l.sectionActivity),
              GroupCard(children: [
                GroupTile(
                  icon: Icons.sos_outlined,
                  hue: sosRed,
                  title: l.myRequests,
                  subtitle: l.openCount(open),
                  onTap: () => context.go('/more/requests'),
                ),
                GroupTile(
                  icon: Icons.volunteer_activism_outlined,
                  title: l.mySupplies,
                  subtitle: offer == null ? l.notOffering : l.offeringList(l.supplies(offer.kinds)),
                  onTap: () => openOfferFlow(context),
                ),
                if (deliveriesVisible(scope))
                  GroupTile(
                    icon: Icons.local_shipping_outlined,
                    hue: Hues.transport,
                    title: l.deliveries,
                    subtitle: l.deliveriesSub,
                    onTap: () => context.go(deliveriesPath),
                  ),
              ]),
              GroupHeader(l.sectionNetwork),
              GroupCard(children: [
                GroupTile(
                  icon: network.internet ? Icons.cloud_done_outlined : Icons.cloud_off,
                  hue: Hues.communication,
                  title: l.networkTitle,
                  subtitle: '${network.internet ? l.statusOnline : l.statusOffline}  ·  '
                      '${l.lastSyncAgo(l.timeAgo(network.lastSync))}',
                  onTap: () => context.go(networkPath),
                ),
                GroupTile(
                  icon: Icons.download_for_offline_outlined,
                  hue: Hues.water,
                  title: l.downloadsTitle,
                  subtitle: package.updateAvailable
                      ? l.packageUpdate(package.version)
                      : l.packageUpToDate(l.timeAgo(package.downloadedAt!)),
                  onTap: () => context.go(downloadsPath),
                ),
                GroupTile(
                  icon: Icons.verified_outlined,
                  hue: Hues.police,
                  title: l.orgsTitle,
                  subtitle: l.orgCount(repo.organizations.value.length),
                  onTap: () => context.go('/more/organizations'),
                ),
              ]),
              GroupHeader(l.sectionSettings),
              GroupCard(children: [
                GroupTile(
                  icon: Icons.contact_phone_outlined,
                  hue: sosRed,
                  title: l.sosContactsTitle,
                  subtitle: l.sosContactsCount(settings.emergencyContacts.length),
                  onTap: () => context.go(emergencyContactsPath),
                ),
                GroupTile(
                  icon: Icons.person_outline,
                  hue: Hues.shelter,
                  title: l.account,
                  subtitle: scope.auth.isSignedIn
                      ? '${l.signedInAs(scope.auth.me.name)} · ${l.role(role)}'
                      : l.guestMode,
                  onTap: () => context.go('/more/account'),
                ),
                GroupTile(
                  icon: Icons.translate,
                  hue: Hues.food,
                  title: l.language,
                  subtitle: supportedLanguages[settings.language] ?? l.languageSystem,
                  onTap: () => context.go('/more/language'),
                ),
                GroupTile(
                  icon: Icons.accessibility_new,
                  hue: Hues.tools,
                  title: l.display,
                  subtitle: l.displaySub((settings.textScale * 100).round()),
                  onTap: () => context.go('/more/display'),
                ),
                GroupTile(
                  icon: Icons.lock_outline,
                  hue: Hues.other,
                  title: l.privacy,
                  subtitle: settings.lockOnOpen ? l.phoneLockOn : l.phoneLockOff,
                  onTap: () => context.go('/more/privacy'),
                ),
              ]),
              if (role.atLeast(Role.manager)) ...[
                GroupHeader(l.sectionManage),
                GroupCard(children: [
                  GroupTile(
                    icon: Icons.tune,
                    hue: Hues.power,
                    title: l.manage,
                    subtitle: l.manageSub,
                    onTap: () => context.go('/more/manage'),
                  ),
                  if (role.atLeast(Role.admin))
                    GroupTile(
                      icon: Icons.admin_panel_settings_outlined,
                      hue: Hues.medical,
                      title: l.admin,
                      subtitle: l.adminSub,
                      onTap: () => context.go('/more/admin'),
                    ),
                ]),
              ],
            ],
          );
        },
      ),
    );
  }
}
