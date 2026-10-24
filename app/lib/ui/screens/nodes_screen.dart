import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../../nodes/node_store.dart';
import '../components/common.dart';
import '../components/toast.dart';
import '../theme/app_theme.dart';
import 'offline_downloads_screen.dart';
import 'qr_scan_screen.dart';

/// Result of probing one node's /healthz.
class NodeProbe {
  final bool reachable;
  final int? latencyMs;
  const NodeProbe(this.reachable, this.latencyMs);
}

/// Probes a node's /healthz. Cached per address until the screen is refreshed.
final nodeProbeProvider =
    FutureProvider.autoDispose.family<NodeProbe, String>((ref, url) async {
  ref.watch(nodesRevisionProvider);
  final sw = Stopwatch()..start();
  try {
    final r = await http
        .get(Uri.parse('$url/healthz'))
        .timeout(const Duration(seconds: 5));
    return NodeProbe(r.statusCode == 200, sw.elapsedMilliseconds);
  } catch (_) {
    return const NodeProbe(false, null);
  }
});

/// Asks a node for its own pairing info (name + address) so a freshly typed
/// address can be saved under the name the node announces.
Future<NodeAddress?> fetchPairing(String url) async {
  try {
    final r = await http
        .get(Uri.parse('$url/node/v1/pair'))
        .timeout(const Duration(seconds: 4));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final name = (j['name'] as String?)?.trim();
    return NodeAddress(url, (name == null || name.isEmpty) ? null : name);
  } catch (_) {
    return null;
  }
}

/// Saved Resilience Nodes: add by scanning the node's QR or typing its address,
/// rename, choose the active one, check reachability, delete.
class NodesScreen extends ConsumerWidget {
  const NodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final nodes = ref.watch(nodesProvider);
    final activeId = ref.watch(activeNodeIdProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('saved_nodes')),
        actions: [
          IconButton(
            tooltip: l.t('refresh'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(nodesRevisionProvider.notifier).state++,
          ),
        ],
      ),
      floatingActionButton: const _AddNodeMenu(),
      body: SafeArea(
        child: nodes.when(
          loading: () => const SkeletonList(),
          error: (e, _) => const SizedBox.shrink(),
          data: (list) {
            if (list.isEmpty) {
              final outline = Theme.of(context).colorScheme.outline;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.router_outlined, size: 48, color: outline),
                    const SizedBox(height: 12),
                    Text(l.t('no_nodes'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 18,
                            color: outline)),
                    const SizedBox(height: 6),
                    Text(l.t('no_nodes_hint'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            color: outline)),
                  ]),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: list.length,
              separatorBuilder: (_, i) => const Divider(height: 1),
              itemBuilder: (_, i) =>
                  _NodeTile(node: list[i], active: list[i].id == activeId),
            );
          },
        ),
      ),
    );
  }
}

class _NodeTile extends ConsumerWidget {
  final SavedNode node;
  final bool active;
  const _NodeTile({required this.node, required this.active});

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final name = await showDialog<String>(
        context: context, builder: (_) => _NameDialog(initial: node.name));
    if (name == null || name.trim().isEmpty) return;
    await ref.read(nodeStoreProvider).rename(node.id, name);
    ref.read(nodesRevisionProvider.notifier).state++;
    if (context.mounted) Toast.show(context, l.t('node_renamed'));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final store = ref.read(nodeStoreProvider);
    await store.remove(node.id);
    ref.read(nodesRevisionProvider.notifier).state++;
    if (!context.mounted) return;
    Toast.show(context, l.t('node_removed'),
        undoLabel: l.t('undo'), onUndo: () async {
      await store.add(node.url, name: node.name);
      ref.read(nodesRevisionProvider.notifier).state++;
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final probe = ref.watch(nodeProbeProvider(node.url));
    final scheme = Theme.of(context).colorScheme;
    final (String status, Color color) = probe.when(
      loading: () => (l.t('status_checking'), scheme.outline),
      error: (e, _) => (l.t('status_unreachable'), scheme.error),
      data: (p) => p.reachable
          ? ('${l.t('status_reachable')} · ${p.latencyMs} ms', AppTheme.verified)
          : (l.t('status_unreachable'), scheme.error),
    );
    return ListTile(
      isThreeLine: true,
      leading: Icon(active ? Icons.radio_button_checked : Icons.router_rounded,
          color: active ? AppTheme.verified : null),
      title: Text(node.name),
      subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.url),
            Text(active ? '${l.t('active_node')} · $status' : status,
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ]),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OfflineDownloadsScreen(nodeId: node.id))),
      trailing: PopupMenuButton<String>(
        tooltip: l.t('actions'),
        onSelected: (v) async {
          switch (v) {
            case 'rename':
              await _rename(context, ref);
            case 'active':
              await ref.read(nodeStoreProvider).setActive(node.id);
              ref.read(nodesRevisionProvider.notifier).state++;
            case 'copy':
              await Clipboard.setData(ClipboardData(text: node.url));
              if (context.mounted) Toast.show(context, l.t('copied'));
            case 'delete':
              await _delete(context, ref);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'rename', child: Text(l.t('rename'))),
          if (!active)
            PopupMenuItem(value: 'active', child: Text(l.t('set_active'))),
          PopupMenuItem(value: 'copy', child: Text(l.t('copy'))),
          PopupMenuItem(value: 'delete', child: Text(l.t('remove'))),
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  final String initial;
  const _NameDialog({required this.initial});
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _c = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return AlertDialog(
      title: Text(l.t('rename')),
      content: TextField(
        controller: _c,
        autofocus: true,
        decoration: InputDecoration(labelText: l.t('node_name')),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l.t('cancel'))),
        FilledButton(
            onPressed: () => Navigator.pop(context, _c.text),
            child: Text(l.t('save'))),
      ],
    );
  }
}

/// Bottom action: collapsed "Add node", expands to Scan QR / Enter address.
class _AddNodeMenu extends ConsumerStatefulWidget {
  const _AddNodeMenu();
  @override
  ConsumerState<_AddNodeMenu> createState() => _AddNodeMenuState();
}

class _AddNodeMenuState extends ConsumerState<_AddNodeMenu> {
  bool _open = false;

  Future<void> _save(BuildContext context, NodeAddress addr) async {
    final l = L10n.of(context);
    // Prefer the name the node announces when the user typed only an address.
    var name = addr.name;
    name ??= (await fetchPairing(addr.url))?.name;
    await ref.read(nodeStoreProvider).add(addr.url, name: name);
    ref.read(nodesRevisionProvider.notifier).state++;
    if (context.mounted) Toast.show(context, l.t('node_saved'));
  }

  Future<void> _scan(BuildContext context) async {
    final l = L10n.of(context);
    final code = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (code == null || !context.mounted) return;
    if (code == QrScanScreen.manualEntry) return _enter(context);
    final addr = parseNodeAddress(code);
    if (addr == null) {
      Toast.show(context, l.t('invalid_node_code'), urgent: true);
      return;
    }
    await _save(context, addr);
  }

  Future<void> _enter(BuildContext context) async {
    final l = L10n.of(context);
    final text = await showDialog<String>(
        context: context, builder: (_) => const _AddressDialog());
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    final addr = parseNodeAddress(text);
    if (addr == null) {
      Toast.show(context, l.t('invalid_node_code'), urgent: true);
      return;
    }
    await _save(context, addr);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    Widget mini(IconData icon, String label, Future<void> Function() run) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FloatingActionButton.extended(
            heroTag: label,
            onPressed: () {
              setState(() => _open = false);
              run();
            },
            icon: Icon(icon),
            label: Text(label),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open) ...[
          mini(Icons.keyboard_rounded, l.t('enter_address'),
              () => _enter(context)),
          mini(Icons.qr_code_scanner_rounded, l.t('scan_node_qr'),
              () => _scan(context)),
        ],
        FloatingActionButton.extended(
          heroTag: 'add_node',
          onPressed: () => setState(() => _open = !_open),
          icon: Icon(_open ? Icons.close_rounded : Icons.add_rounded),
          label: Text(_open ? l.t('close') : l.t('add_node')),
        ),
      ],
    );
  }
}

class _AddressDialog extends StatefulWidget {
  const _AddressDialog();
  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return AlertDialog(
      title: Text(l.t('enter_address')),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration:
            InputDecoration(labelText: l.t('node_address'), hintText: l.t('node_hint')),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l.t('cancel'))),
        FilledButton(
            onPressed: () => Navigator.pop(context, _c.text),
            child: Text(l.t('add'))),
      ],
    );
  }
}
