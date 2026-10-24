import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../models/help.dart';
import '../../models/mesh_message.dart';
import '../../models/network.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/surfaces.dart';
import '../../ui/theme.dart';
import '../../ui/visuals.dart';

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
          Widget row(IconData icon, String title, bool ok, String value) => GroupTile(
                icon: icon,
                hue: ok ? c.primary : c.outline,
                title: title,
                subtitle: value,
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
            padding: EdgeInsets.only(bottom: bottomClearance(context)),
            children: [
              GroupHeader(l.howItTravels),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Column(
                      children: [
                        for (final (i, (icon, title, sub, ok)) in path.indexed)
                          _PathStep(
                            icon: icon,
                            title: title,
                            subtitle: sub,
                            ok: ok,
                            // The line to the next step lights up when both work.
                            linkOk: i < path.length - 1 ? ok && path[i + 1].$4 : null,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GroupCard(children: [
                row(Icons.public, l.netInternet, n.internet,
                    n.internet ? l.netConnected : l.netNotConnected),
                row(Icons.phone_android, l.netPeers, n.peers > 0, l.peersCount(n.peers)),
                row(Icons.router_outlined, l.netNode, n.node,
                    n.node ? l.netConnected : l.netNotConnected),
                row(Icons.cell_tower, l.netLora, n.lora, n.lora ? l.netConnected : l.netNotConnected),
              ]),
              const SizedBox(height: 16),
              GroupCard(children: [
                GroupTile(
                  icon: Icons.sync,
                  hue: Hues.water,
                  title: l.netLastLocal,
                  subtitle: l.timeAgo(n.lastSync),
                ),
                GroupTile(
                  icon: Icons.cloud_sync_outlined,
                  hue: Hues.communication,
                  title: l.netLastGlobal,
                  subtitle: l.timeAgo(n.lastGlobalSync),
                ),
                GroupTile(
                  icon: Icons.outbox_outlined,
                  hue: queued > 0 ? Hues.caution : Hues.other,
                  title: l.queuedCount(queued),
                ),
                GroupTile(
                  icon: Icons.settings_input_antenna,
                  title: l.viewRadios,
                  onTap: () => context.go('/more/network/radios'),
                ),
              ]),
              const SizedBox(height: 16),
              GroupCard(children: [
                SwitchListTile(
                  secondary: const IconTile(icon: Icons.science_outlined, color: Hues.tools, size: 44),
                  title: Text(l.demoInternet),
                  subtitle: Text(l.demoInternetSub),
                  value: n.internet,
                  onChanged: (v) {
                    Haptics.tick();
                    repo.setInternet(v);
                  },
                ),
              ]),
            ],
          );
        },
      ),
    );
  }
}

/// One step on the path a request travels, joined to the next by a line.
class _PathStep extends StatelessWidget {
  const _PathStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ok,
    required this.linkOk,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool ok;

  /// Null for the last step, which has no line after it.
  final bool? linkOk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              IconTile(icon: icon, color: ok ? c.primary : c.outline, size: 46, solid: ok),
              if (linkOk != null)
                Expanded(
                  child: Container(
                    width: 4,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: linkOk! ? c.primary : c.outlineVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  Text(subtitle, style: TextStyle(color: c.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Icon(
              ok ? Icons.check_circle : Icons.pending_outlined,
              color: ok ? c.primary : c.outline,
            ),
          ),
        ],
      ),
    );
  }
}
