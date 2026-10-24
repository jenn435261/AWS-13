import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/endpoints.dart';
import '../../l10n/labels.dart';
import '../../models/network.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/surfaces.dart';
import '../../ui/theme.dart';
import '../../ui/visuals.dart';

/// Connectivity in plain words (Spec section 65): one line saying whether
/// things are going out, the five ways this phone can reach others, and
/// the detail of each link under Advanced.
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
                  semanticLabel: ok ? l.netConnected : l.netNotConnected,
                ),
              );
          String connected(bool ok) => ok ? l.netConnected : l.netNotConnected;
          final radios =
              repo.nodes.value.where((node) => node.enabled && node.isOnline).length;

          return ListView(
            padding: EdgeInsets.only(bottom: bottomClearance(context)),
            children: [
              const SizedBox(height: 8),
              NetworkSummary(status: n),
              GroupHeader(l.netConnections),
              GroupCard(children: [
                row(
                  Icons.cloud_outlined,
                  l.netAws,
                  n.cloudReachable,
                  n.internet
                      ? l.netAwsDirect
                      : n.gatewayOnline
                          ? l.netAwsMesh
                          : l.netAwsNone,
                ),
                row(Icons.router_outlined, l.netNode, n.node, connected(n.node)),
                row(Icons.cell_tower, l.netLora, n.lora, connected(n.lora)),
                row(Icons.phone_android, l.netPeers, n.peers > 0, l.peersCount(n.peers)),
                row(Icons.public, l.netInternet, n.internet, connected(n.internet)),
              ]),
              const SizedBox(height: 16),
              GroupCard(children: [
                GroupTile(
                  icon: Icons.settings_input_antenna,
                  title: l.viewRadios,
                  subtitle: l.radiosNearby(radios),
                  onTap: () => context.go('/more/network/radios'),
                ),
              ]),
              const SizedBox(height: 16),
              GroupCard(children: [_Advanced(status: n, radios: radios)]),
            ],
          );
        },
      ),
    );
  }
}

/// The one line at the top: sending, waiting (and how much), all sent, or
/// no connection. Read out by screen readers when it changes.
class NetworkSummary extends StatelessWidget {
  const NetworkSummary({super.key, required this.status});

  final NetworkStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final n = status;
    final (icon, hue, title, subtitle) = n.queued > 0 && n.hasRoute
        ? (Icons.upload_outlined, c.primary, l.netStatusSending, l.netStatusSendingSub(n.queued))
        : n.queued > 0
            ? (Icons.outbox_outlined, Hues.cautionInk, l.netStatusWaiting(n.queued), l.netStatusWaitingSub)
            : n.hasRoute
                ? (Icons.check_circle_outline, c.primary, l.netStatusSent, l.lastSyncAgo(l.timeAgo(n.lastSync)))
                : (Icons.cloud_off_outlined, c.outline, l.netStatusOffline, l.netStatusOfflineSub);

    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconTile(icon: icon, color: hue, size: 52),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: c.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Each link on its own, sync times, the path a request takes, and the
/// demo switch: useful, but not what most people need first.
class _Advanced extends StatelessWidget {
  const _Advanced({required this.status, required this.radios});

  final NetworkStatus status;
  final int radios;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final n = status;

    // Links as the transports report them; from the summary flags when
    // the repository gives no detail.
    final links = n.links.isNotEmpty
        ? n.links
        : [
            LinkStatus(kind: LinkKind.cloud, up: n.internet),
            LinkStatus(kind: LinkKind.node, up: n.node),
            LinkStatus(kind: LinkKind.lora, up: n.lora),
            LinkStatus(kind: LinkKind.bluetooth, up: n.peers > 0, peers: n.peers),
          ];

    Widget link(LinkStatus s) {
      final (icon, title) = switch (s.kind) {
        LinkKind.cloud => (Icons.cloud_outlined, l.netLinkCloud),
        LinkKind.node => (Icons.router_outlined, l.netLinkNode),
        LinkKind.lora => (Icons.cell_tower, l.netLinkLora),
        LinkKind.wifi => (Icons.wifi, l.netLinkWifi),
        LinkKind.bluetooth => (Icons.bluetooth, l.netLinkBluetooth),
      };
      final nearby = s.kind == LinkKind.wifi || s.kind == LinkKind.bluetooth;
      final state = !s.available
          ? l.netLinkUnavailable
          : !s.up
              ? l.netLinkDown
              : [
                  l.netLinkUp,
                  if (nearby) l.peersCount(s.peers),
                  if (s.kind == LinkKind.node) Uri.parse(nodeBaseUrl).authority,
                ].join('  ·  ');
      return GroupTile(
        icon: icon,
        hue: s.up ? c.primary : c.outline,
        title: title,
        subtitle: s.lastAck == null
            ? state
            : '$state\n${l.netLinkConfirmed(l.timeAgo(s.lastAck!))}',
        trailing: Icon(
          s.up ? Icons.check_circle : Icons.cancel_outlined,
          color: s.up ? c.primary : c.outline,
          semanticLabel: s.up ? l.netConnected : l.netNotConnected,
        ),
      );
    }

    // The path a request takes, step by step, and which steps work now.
    final path = [
      (Icons.smartphone, l.travelPhone, l.travelPhoneSub, true),
      (Icons.cell_tower, l.travelMesh, '${l.radiosNearby(radios)}. ${l.travelMeshSub}',
          radios > 0 || n.node),
      (Icons.cloud_outlined, l.travelCloud,
          n.gatewayOnline ? l.travelCloudOnline : l.travelCloudOffline, n.gatewayOnline),
      (Icons.groups_outlined, l.travelHelpers, l.travelHelpersSub, n.gatewayOnline),
    ];

    Widget divider() => Divider(height: 1, indent: 76, color: c.outlineVariant);

    return ExpansionTile(
      leading: const IconTile(icon: Icons.tune, color: Hues.other, size: 44),
      title: Text(l.netAdvanced),
      subtitle: Text(l.netAdvancedSub),
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onExpansionChanged: (_) => Haptics.tick(),
      children: [
        for (final s in links) ...[divider(), link(s)],
        divider(),
        GroupTile(
          icon: Icons.sync,
          hue: Hues.water,
          title: l.netLastLocal,
          subtitle: l.timeAgo(n.lastSync),
        ),
        divider(),
        GroupTile(
          icon: Icons.cloud_sync_outlined,
          hue: Hues.communication,
          title: l.netLastGlobal,
          subtitle: l.timeAgo(n.lastGlobalSync),
        ),
        divider(),
        GroupTile(
          icon: Icons.outbox_outlined,
          hue: n.queued > 0 ? Hues.caution : Hues.other,
          title: l.queuedCount(n.queued),
        ),
        divider(),
        GroupHeader(l.howItTravels),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
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
        divider(),
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
      ],
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
