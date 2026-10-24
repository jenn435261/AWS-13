import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../identity/identity_store.dart';
import '../../l10n/strings.dart';
import '../components/toast.dart';
import '../../app/providers.dart';
import 'location_share_screen.dart';
import 'my_posts_screen.dart';
import 'network_status_screen.dart';
import 'nodes_screen.dart';
import 'provider_screen.dart';
import 'offline_downloads_screen.dart';
import 'settings_screen.dart';
import 'trusted_orgs_screen.dart';

/// The "More" hub: itemized secondary actions with icons + readable labels
/// (keeps the primary screens uncluttered). Includes data controls
/// (clear cache / full wipe) and the entry to Settings/Network/Location.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('nav_more'))),
      body: SafeArea(
        child: ListView(
          children: [
            _tile(context, Icons.my_location_rounded, l.t('share_location'),
                onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const LocationShareScreen()));
            }),
            _tile(context, Icons.inventory_2_outlined, l.t('my_supplies'),
                onTap: () => _open(context, const MyPostsScreen(requests: false))),
            _tile(context, Icons.help_outline_rounded, l.t('my_requests'),
                onTap: () => _open(context, const MyPostsScreen(requests: true))),
            _tile(context, Icons.admin_panel_settings_outlined, l.t('provider_tools'),
                subtitle: ref.watch(isVerifiedProviderProvider)
                    ? l.t('you_are_provider')
                    : l.t('you_are_community'),
                onTap: () => _open(context, const ProviderScreen())),
            _tile(context, Icons.router_outlined, l.t('saved_nodes'),
                onTap: () => _open(context, const NodesScreen())),
            _tile(context, Icons.download_outlined, l.t('offline_downloads'),
                onTap: () => _open(context, const OfflineDownloadsScreen())),
            _tile(context, Icons.network_check_rounded, l.t('network_status'),
                onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const NetworkStatusScreen()));
            }),
            _tile(context, Icons.verified_outlined, l.t('trusted_organizations'),
                onTap: () => _open(context, const TrustedOrgsScreen())),
            _tile(context, Icons.settings_outlined, l.t('settings'), onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            }),
            const Divider(height: 24),
            // Data controls — cache clear (undoable toast) and full wipe
            // (confirm dialog; biometric-gated in production).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(l.t('data_controls'),
                  style: const TextStyle(fontFamily: 'Roboto', 
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            _tile(context, Icons.cleaning_services_outlined, l.t('clear_cache'),
                onTap: () {
              HapticFeedback.mediumImpact();
              // The only cache is the derived world-state projection (rebuilt
              // from the signed log); no event data is touched.
              ref.invalidate(worldStateProvider);
              ref.invalidate(cloudProbeProvider);
              Toast.show(context, l.t('cache_cleared'));
            }),
            _tile(
              context,
              Icons.delete_forever_outlined,
              l.t('full_wipe'),
              danger: true,
              onTap: () => _confirmWipe(context, ref, l),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmWipe(
      BuildContext context, WidgetRef ref, L10n l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('full_wipe')),
        content: Text(l.t('full_wipe_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.t('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.t('erase')),
          ),
        ],
      ),
    );
    if (ok == true) {
      HapticFeedback.heavyImpact();
      await ref.read(databaseProvider).wipeAll();
      await IdentityStore(ref.read(secretStoreProvider)).clear();
      ref.invalidate(identityProvider);
      ref.invalidate(contactsProvider);
      ref.invalidate(nodesProvider);
      ref.invalidate(activeNodeIdProvider);
      ref.invalidate(packagesProvider);
      ref.invalidate(trustRootsProvider);
      ref.invalidate(trustRootsLoadedProvider);
      ref.invalidate(trustedRootsListProvider);
      ref.invalidate(myPositionProvider);
      ref.invalidate(worldStateProvider);
      bumpWorld(ref);
      if (context.mounted) {
        Toast.show(context, l.t('data_erased'), urgent: true);
      }
    }
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _tile(BuildContext context, IconData icon, String title,
      {String? subtitle, VoidCallback? onTap, bool danger = false}) {
    final color = danger ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap ?? () {},
    );
  }
}
