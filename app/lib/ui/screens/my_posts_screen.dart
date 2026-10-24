
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../../state/derived_state.dart';
import '../components/common.dart';
import '../components/toast.dart';
import '../components/trust_badges.dart';
import '../theme/app_theme.dart';
import 'supply_editor_screen.dart';

/// "My Requests" (what I asked for) or "My Supplies" (what I offer), read from
/// the local event log projection and filtered to what I authored. Supplies can
/// be created, edited, restocked, marked out of stock, taken down and relisted.
class MyPostsScreen extends ConsumerWidget {
  const MyPostsScreen({super.key, required this.requests});

  /// true => My Requests; false => My Supplies.
  final bool requests;

  static bool _same(Uint8List a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final world = ref.watch(worldStateProvider);
    final me = ref.watch(identityProvider);

    return Scaffold(
      appBar: AppBar(
          title: Text(requests ? l.t('my_requests') : l.t('my_supplies'))),
      floatingActionButton: requests
          ? null
          : FloatingActionButton.extended(
              heroTag: 'add_supply',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SupplyEditorScreen())),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.t('add_supply')),
            ),
      body: SafeArea(
        child: world.when(
          loading: () => const SkeletonList(),
          error: (e, _) => _empty(context, l, Icons.error_outline_rounded,
              requests ? l.t('no_requests') : l.t('no_supplies'), ''),
          data: (w) {
            final mine = me.valueOrNull?.keys.signingPublicKey;
            if (mine == null) return const SkeletonList();
            return requests
                ? _requests(context, l, w, mine)
                : _supplies(context, ref, l, w, mine);
          },
        ),
      ),
    );
  }

  Widget _requests(
      BuildContext context, L10n l, WorldState w, List<int> mine) {
    final rows = w.helpRequests.where((r) => _same(r.author, mine)).toList();
    if (rows.isEmpty) {
      return _empty(context, l, Icons.help_outline_rounded, l.t('no_requests'),
          l.t('no_requests_hint'));
    }
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, i) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final r = rows[i];
        final cats =
            r.body.categories.map((c) => categoryLabel(l, c)).join(', ');
        return ListTile(
          leading: const Icon(Icons.help_outline_rounded),
          title: Text(cats.isEmpty ? '—' : cats),
          subtitle: r.body.freeform.isEmpty ? null : Text(r.body.freeform),
        );
      },
    );
  }

  Widget _supplies(BuildContext context, WidgetRef ref, L10n l, WorldState w,
      List<int> mine) {
    final supplies = w.resources.values
        .where((r) => _same(r.owner, mine))
        .toList()
      ..sort((a, b) => a.resource.title.compareTo(b.resource.title));
    final offers = w.helpOffers.where((o) => _same(o.author, mine)).toList();
    if (supplies.isEmpty && offers.isEmpty) {
      return _empty(context, l, Icons.inventory_2_outlined, l.t('no_supplies'),
          l.t('no_supplies_hint'));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final s in supplies) ...[
          _SupplyTile(view: s),
          const Divider(height: 1),
        ],
        if (offers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(l.t('offers_sent'),
                style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
          for (final o in offers)
            ListTile(
              leading: const Icon(Icons.volunteer_activism_rounded),
              title: Text(
                  o.body.categories.map((c) => categoryLabel(l, c)).join(', ')),
              subtitle: o.body.notes.isEmpty ? null : Text(o.body.notes),
            ),
        ],
      ],
    );
  }

  Widget _empty(BuildContext context, L10n l, IconData icon, String title,
      String hint) {
    final outline = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: outline),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Roboto', fontSize: 18, color: outline)),
            if (hint.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Roboto', fontSize: 16, color: outline)),
            ],
          ],
        ),
      ),
    );
  }
}

enum _SupplyAction { edit, quantity, ranOut, takeDown, relist }

class _SupplyTile extends ConsumerWidget {
  final ResourceView view;
  const _SupplyTile({required this.view});

  Future<void> _quantityDialog(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final qty =
        TextEditingController(text: view.inventory?.quantity.toString() ?? '');
    final unit = TextEditingController(text: view.inventory?.unit ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('update_quantity')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: qty,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l.t('number')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: unit,
            decoration: InputDecoration(
                labelText: l.t('unit'), hintText: l.t('unit_hint')),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.t('save'))),
        ],
      ),
    );
    final n = int.tryParse(qty.text.trim());
    final u = unit.text.trim();
    // Controllers are disposed after the dialog's exit animation completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        qty.dispose();
        unit.dispose();
      });
    });
    if (ok != true || n == null) return;
    final svc = await ref.read(supplyServiceProvider.future);
    await svc.setQuantity(view.resourceId, n, u);
    bumpWorld(ref);
    if (context.mounted) Toast.show(context, l.t('supply_saved'));
  }

  Future<void> _run(
      BuildContext context, WidgetRef ref, _SupplyAction a) async {
    final l = L10n.of(context);
    switch (a) {
      case _SupplyAction.edit:
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SupplyEditorScreen(editing: view)));
        return;
      case _SupplyAction.quantity:
        return _quantityDialog(context, ref);
      case _SupplyAction.ranOut:
        final svc = await ref.read(supplyServiceProvider.future);
        await svc.markRanOut(view.resourceId, view.inventory?.unit ?? '');
        bumpWorld(ref);
        if (context.mounted) Toast.show(context, l.t('marked_out'));
      case _SupplyAction.takeDown:
        final svc = await ref.read(supplyServiceProvider.future);
        await svc.takeDown(view.resourceId);
        bumpWorld(ref);
        if (context.mounted) {
          Toast.show(context, l.t('supply_taken_down'),
              undoLabel: l.t('undo'), onUndo: () async {
            await svc.relist(view.resource);
            bumpWorld(ref);
          });
        }
      case _SupplyAction.relist:
        final svc = await ref.read(supplyServiceProvider.future);
        await svc.relist(view.resource);
        bumpWorld(ref);
        if (context.mounted) Toast.show(context, l.t('supply_relisted'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final r = view.resource;
    final scheme = Theme.of(context).colorScheme;
    final inv = view.inventory;
    final out = inv != null && inv.quantity == 0;

    final (String status, Color color) = view.withdrawn
        ? (l.t('status_taken_down'), scheme.outline)
        : out
            ? (l.t('status_out'), scheme.error)
            : (l.t('status_listed'), AppTheme.verified);

    final details = <String>[
      categoryLabel(l, r.category),
      if (inv != null)
        '${inv.quantity}${inv.unit.isEmpty ? '' : ' ${inv.unit}'}',
      if (r.availableUntilMs.toInt() > 0)
        '${l.t('avail_until')} ${MaterialLocalizations.of(context).formatMediumDate(DateTime.fromMillisecondsSinceEpoch(r.availableUntilMs.toInt()))}',
      if (!r.hasLocation()) l.t('without_location'),
    ];

    return ListTile(
      isThreeLine: true,
      leading: Icon(iconForCategory(r.category)),
      title: Text(r.title.isEmpty ? categoryLabel(l, r.category) : r.title,
          style: TextStyle(
              decoration: view.withdrawn ? TextDecoration.lineThrough : null)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(details.join(' · ')),
          const SizedBox(height: 4),
          Text(status,
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
      onTap: () => _run(context, ref, _SupplyAction.edit),
      trailing: PopupMenuButton<_SupplyAction>(
        tooltip: l.t('actions'),
        onSelected: (a) => _run(context, ref, a),
        itemBuilder: (_) => [
          PopupMenuItem(
              value: _SupplyAction.edit, child: Text(l.t('edit_supply'))),
          PopupMenuItem(
              value: _SupplyAction.quantity,
              child: Text(l.t('update_quantity'))),
          if (!view.withdrawn && !out)
            PopupMenuItem(
                value: _SupplyAction.ranOut, child: Text(l.t('mark_out'))),
          if (view.withdrawn)
            PopupMenuItem(
                value: _SupplyAction.relist, child: Text(l.t('relist')))
          else
            PopupMenuItem(
                value: _SupplyAction.takeDown, child: Text(l.t('take_down'))),
        ],
      ),
    );
  }
}
