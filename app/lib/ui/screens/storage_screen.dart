import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../../packages/region_pack_store.dart';
import '../components/toast.dart';
import 'prepare_now_screen.dart';

/// Storage: the user's downloaded region packs, each with its size, source
/// (Cloud/Node), download state, and a delete action. A partial pack shows
/// `N% of a name, resume` and a Resume button; deleting a verified pack never
/// touches a different pack. First entry answers "how do I download the offline
/// map?".
class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final outline = Theme.of(context).colorScheme.outline;
    final packs =
        ref.watch(regionPacksProvider).valueOrNull ?? const <RegionPack>[];

    return Scaffold(
      appBar: AppBar(title: Text(l.t('storage'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'dl_region',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PrepareNowScreen())),
        icon: const Icon(Icons.download_rounded),
        label: Text(l.t('download_a_region')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            // First-run help: how to download the offline map.
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ListTile(
                leading: const Icon(Icons.help_outline_rounded),
                title: Text(l.t('how_to_download_title'),
                    style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                subtitle: Text(l.t('how_to_download_body'),
                    style: TextStyle(
                        fontFamily: 'Roboto', fontSize: 16, color: outline)),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.t('offline_maps'),
                style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (packs.isEmpty)
              Text(l.t('no_region_packs'),
                  style: TextStyle(
                      fontFamily: 'Roboto', fontSize: 16, color: outline))
            else
              for (final p in packs) _PackCard(pack: p),
          ],
        ),
      ),
    );
  }
}

class _PackCard extends ConsumerWidget {
  final RegionPack pack;
  const _PackCard({required this.pack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final verified = pack.status == PackStatus.verified;
    final resumeLabel = l
        .t('pack_partial_resume')
        .replaceAll('{percent}', '${pack.percent}')
        .replaceAll('{name}', pack.name);
    final subtitle = verified
        ? '${_mb(pack.totalBytes)} · ${l.t('pack_verified')} · ${pack.source}'
        : '$resumeLabel · ${pack.source}';

    return Card(
      child: ListTile(
        leading: Icon(
          verified ? Icons.offline_pin_rounded : Icons.downloading_rounded,
          color: verified ? scheme.primary : scheme.outline,
        ),
        title: Text(pack.name),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!verified)
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PrepareNowScreen())),
                child: Text(l.t('resume')),
              ),
            IconButton(
              tooltip: l.t('delete_pack'),
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _delete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    // Delete this pack's chunks AND its metadata. This is a user-initiated
    // delete of a SPECIFIC pack; it never touches any other pack (the
    // no-premature-delete rule only governs AUTOMATIC replacement, not an
    // explicit user delete).
    await ref.read(regionChunkStoreProvider).deletePack(pack.id);
    await ref.read(regionPackStoreProvider).remove(pack.id);
    ref.read(regionPacksRevisionProvider.notifier).state++;
    if (context.mounted) Toast.show(context, l.t('pack_deleted'));
  }

  static String _mb(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  }
}
