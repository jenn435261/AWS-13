import 'package:flutter/material.dart';

import '../../l10n/labels.dart';
import '../../models/mesh_node.dart';
import '../../models/role.dart';
import '../../state/app_scope.dart';
import '../../ui/empty_state.dart';
import '../../ui/theme.dart';
import '../../utils/format.dart';

class NodesScreen extends StatelessWidget {
  const NodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final isMember = !scope.auth.role.atLeast(Role.manager);

    return Scaffold(
      appBar: AppBar(title: Text(l.network)),
      body: ValueListenableBuilder<List<MeshNode>>(
        valueListenable: scope.repository.nodes,
        builder: (context, all, _) {
          // Members only see nodes a manager has left enabled.
          final nodes = (isMember ? all.where((n) => n.enabled) : all).toList()
            ..sort((a, b) => b.lastHeard.compareTo(a.lastHeard));

          if (nodes.isEmpty) {
            return EmptyState(icon: Icons.cell_tower, message: l.noNodes);
          }
          return ListView.builder(
            padding: EdgeInsets.only(bottom: bottomClearance(context)),
            itemCount: nodes.length,
            itemBuilder: (context, i) => _NodeTile(node: nodes[i]),
          );
        },
      ),
    );
  }
}

String _hops(AppLocalizations l, int hops) =>
    hops == 0 ? l.hopsDirect : l.hopsCount(hops);

class _NodeTile extends StatelessWidget {
  const _NodeTile({required this.node});

  final MeshNode node;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final online = node.isOnline;

    return ListTile(
      // Status is an icon and a word, never color alone.
      leading: Icon(
        online ? Icons.wifi_tethering : Icons.portable_wifi_off,
        color: online ? c.primary : c.outline,
      ),
      title: Text(node.name),
      subtitle: Text(
        [
          online ? l.nodeOnline : l.nodeOffline,
          l.timeAgo(node.lastHeard),
          _hops(l, node.hops),
        ].join('  ·  '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (node.battery != null) Text('${node.battery}%'),
          const SizedBox(width: 4),
          Icon(
            batteryIcon(node.battery),
            color: (node.battery ?? 100) < 20 ? c.error : null,
          ),
        ],
      ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _NodeDetails(node: node),
      ),
    );
  }
}

/// Technical details live one tap away so the list stays clean.
class _NodeDetails extends StatelessWidget {
  const _NodeDetails({required this.node});

  final MeshNode node;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = <(String, String)>[
      (l.nodeId, node.id),
      (l.lastHeard, l.timeAgo(node.lastHeard)),
      (l.battery, node.battery == null ? l.externalPower : '${node.battery}%'),
      (l.signalStrength, node.rssi == null ? '-' : '${node.rssi} dBm'),
      (l.signalNoise, node.snr == null ? '-' : '${node.snr} dB'),
      (l.hopsTitle, _hops(l, node.hops)),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    Text(value),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
