import 'package:flutter/material.dart';

import '../../l10n/labels.dart';
import '../../models/mesh_node.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/theme.dart';

/// Authorized managers (and admins): control which nodes are on the network.
class ManageScreen extends StatelessWidget {
  const ManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.manage)),
      body: ValueListenableBuilder<List<MeshNode>>(
        valueListenable: repo.nodes,
        builder: (context, nodes, _) => ListView(
          padding: EdgeInsets.only(bottom: bottomClearance(context)),
          children: [
            ListTile(title: Text(l.manageHint)),
            for (final node in nodes)
              SwitchListTile(
                secondary: const Icon(Icons.cell_tower),
                title: Text(node.name),
                subtitle: Text('${node.id}  ·  ${l.timeAgo(node.lastHeard)}'),
                value: node.enabled,
                onChanged: (on) {
                  Haptics.tick();
                  repo.setNodeEnabled(node.id, on);
                },
              ),
          ],
        ),
      ),
    );
  }
}
