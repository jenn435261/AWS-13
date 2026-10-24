import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../models/help.dart';
import '../../models/mesh_message.dart';
import '../../models/network.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/theme.dart';

/// Connectivity in plain words (Spec section 65): what this phone can reach,
/// and when it last synced nearby and with the cloud.
class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l.networkTitle)),
      body: ValueListenableBuilder<NetworkStatus>(
        valueListenable: repo.network,
        builder: (context, n, _) {
          Widget row(IconData icon, String title, bool ok, String value) => ListTile(
                leading: Icon(icon),
                title: Text(title),
                subtitle: Text(value),
                trailing: Icon(
                  ok ? Icons.check_circle : Icons.cancel_outlined,
                  color: ok ? c.primary : c.outline,
                ),
              );
          final queued = repo.requests.value
                  .where((r) => r.mine && r.stage == RequestStage.saved)
                  .length +
              repo.messages.value.where((m) => m.status == DeliveryStatus.queued).length;

          final radios =
              repo.nodes.value.where((node) => node.enabled && node.isOnline).length;
          // The path a request takes, step by step, and which steps work now.
          final path = [
            (Icons.smartphone, l.travelPhone, l.travelPhoneSub, true),
            (Icons.cell_tower, l.travelMesh,
                '${l.radiosNearby(radios)}. ${l.travelMeshSub}', radios > 0 || n.node),
            (Icons.cloud_outlined, l.travelCloud,
                n.gatewayOnline ? l.travelCloudOnline : l.travelCloudOffline, n.gatewayOnline),
            (Icons.groups_outlined, l.travelHelpers, l.travelHelpersSub, n.gatewayOnline),
          ];

          return ListView(
            padding: const EdgeInsets.only(bottom: helpButtonClearance + 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(l.howItTravels, style: Theme.of(context).textTheme.titleLarge),
              ),
              for (final (icon, title, sub, ok) in path)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ok ? c.primaryContainer : c.surfaceContainerHighest,
                    foregroundColor: ok ? c.onPrimaryContainer : c.onSurfaceVariant,
                    child: Icon(icon),
                  ),
                  title: Text(title),
                  subtitle: Text(sub),
                  trailing: Icon(
                    ok ? Icons.check_circle : Icons.pending_outlined,
                    color: ok ? c.primary : c.outline,
                  ),
                ),
              const Divider(),
              row(Icons.public, l.netInternet, n.internet,
                  n.internet ? l.netConnected : l.netNotConnected),
              row(Icons.phone_android, l.netPeers, n.peers > 0, l.peersCount(n.peers)),
              row(Icons.router_outlined, l.netNode, n.node,
                  n.node ? l.netConnected : l.netNotConnected),
              row(Icons.cell_tower, l.netLora, n.lora, n.lora ? l.netConnected : l.netNotConnected),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.sync),
                title: Text(l.netLastLocal),
                subtitle: Text(l.timeAgo(n.lastSync)),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_sync_outlined),
                title: Text(l.netLastGlobal),
                subtitle: Text(l.timeAgo(n.lastGlobalSync)),
              ),
              ListTile(
                leading: const Icon(Icons.outbox_outlined),
                title: Text(l.queuedCount(queued)),
              ),
              ListTile(
                leading: const Icon(Icons.settings_input_antenna),
                title: Text(l.viewRadios),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/more/network/radios'),
              ),
              const Divider(),
              SwitchListTile(
                secondary: const Icon(Icons.science_outlined),
                title: Text(l.demoInternet),
                subtitle: Text(l.demoInternetSub),
                value: n.internet,
                onChanged: (v) {
                  Haptics.tick();
                  repo.setInternet(v);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
