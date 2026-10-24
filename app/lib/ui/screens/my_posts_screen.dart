import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../gen/resilience/v1/event.pb.dart';
import '../../l10n/strings.dart';
import '../components/common.dart';
import '../components/trust_badges.dart';

/// "My Requests" (what I asked for) or "My Supplies" (what I offered / own),
/// read straight from the local event log projection — the same data the map
/// uses, filtered to events I authored.
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
      body: SafeArea(
        child: world.when(
          loading: () => const SkeletonList(),
          error: (e, _) => _empty(context, l, Icons.error_outline_rounded,
              requests ? l.t('no_requests') : l.t('no_supplies'), ''),
          data: (w) {
            final mine = me.valueOrNull?.keys.signingPublicKey;
            if (mine == null) return const SkeletonList();
            final rows = <_Row>[];
            if (requests) {
              for (final r in w.helpRequests) {
                if (!_same(r.author, mine)) continue;
                rows.add(_Row(
                    r.body.categories, r.body.freeform, Icons.help_outline_rounded));
              }
            } else {
              for (final o in w.helpOffers) {
                if (!_same(o.author, mine)) continue;
                rows.add(_Row(o.body.categories, o.body.notes,
                    Icons.volunteer_activism_rounded));
              }
              for (final res in w.resources.values) {
                if (!_same(res.owner, mine)) continue;
                rows.add(_Row([res.resource.category], res.resource.title,
                    Icons.inventory_2_outlined));
              }
            }
            if (rows.isEmpty) {
              return _empty(
                  context,
                  l,
                  requests
                      ? Icons.help_outline_rounded
                      : Icons.inventory_2_outlined,
                  requests ? l.t('no_requests') : l.t('no_supplies'),
                  requests ? l.t('no_requests_hint') : l.t('no_supplies_hint'));
            }
            return ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, i) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = rows[i];
                final cats =
                    r.categories.map((c) => categoryLabel(l, c)).join(', ');
                return ListTile(
                  leading: Icon(r.icon),
                  title: Text(cats.isEmpty ? '—' : cats),
                  subtitle: r.note.isEmpty ? null : Text(r.note),
                );
              },
            );
          },
        ),
      ),
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

class _Row {
  final List<ResourceCategory> categories;
  final String note;
  final IconData icon;
  _Row(this.categories, this.note, this.icon);
}
