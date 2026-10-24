import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../identity/identity_card.dart';
import '../../l10n/strings.dart';
import '../../trust/root_repo.dart';
import '../components/common.dart';
import '../components/toast.dart';
import '../theme/app_theme.dart';

/// The organization roots this device trusts. A root is never learned from the
/// event log (anyone could mint a badge that way); the user chooses it here:
/// from a saved contact, by pasting a key, or by trusting their own key when
/// they are founding an organization. Choices persist across restarts.
class TrustedOrgsScreen extends ConsumerWidget {
  const TrustedOrgsScreen({super.key});

  Future<void> _trust(BuildContext context, WidgetRef ref, List<int> key,
      String name) async {
    final l = L10n.of(context);
    store(ref).add(key);
    await ref.read(trustRootRepoProvider).add(key, name);
    ref.read(trustRevisionProvider.notifier).state++;
    bumpWorld(ref);
    if (context.mounted) Toast.show(context, l.t('org_trusted'));
  }

  Future<void> _untrust(
      BuildContext context, WidgetRef ref, TrustedRoot r) async {
    final l = L10n.of(context);
    store(ref).remove(r.bytes);
    await ref.read(trustRootRepoProvider).remove(r.bytes);
    ref.read(trustRevisionProvider.notifier).state++;
    bumpWorld(ref);
    if (context.mounted) {
      Toast.show(context, l.t('org_untrusted'),
          undoLabel: l.t('undo'), onUndo: () => _trust(context, ref, r.bytes, r.name));
    }
  }

  dynamic store(WidgetRef ref) => ref.read(trustRootsProvider);

  Future<void> _fromContacts(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final contacts = await ref.read(contactsProvider.future);
    if (!context.mounted) return;
    if (contacts.isEmpty) {
      Toast.show(context, l.t('no_contacts_for_org'));
      return;
    }
    final picked = await showModalBottomSheet<IdentityCard>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.t('trust_from_contacts'),
                style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
          for (final c in contacts)
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(c.displayName.isEmpty ? c.resilienceId : c.displayName),
              subtitle: Text(c.resilienceId),
              onTap: () => Navigator.pop(ctx, c),
            ),
        ]),
      ),
    );
    if (picked != null && context.mounted) {
      await _trust(context, ref, picked.signingPublicKey,
          picked.displayName.isEmpty ? picked.resilienceId : picked.displayName);
    }
  }

  Future<void> _mine(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('trust_my_key')),
        content: Text(l.t('trust_my_key_explain')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.t('confirm'))),
        ],
      ),
    );
    if (ok != true) return;
    final me = await ref.read(identityProvider.future);
    if (context.mounted) {
      await _trust(context, ref, me.keys.signingPublicKey, me.displayName);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final roots = ref.watch(trustedRootsListProvider);
    final outline = Theme.of(context).colorScheme.outline;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('trusted_organizations'))),
      floatingActionButton: PopupMenuButton<int>(
        tooltip: l.t('trust_organization'),
        onSelected: (v) => v == 0 ? _fromContacts(context, ref) : _mine(context, ref),
        itemBuilder: (_) => [
          PopupMenuItem(value: 0, child: Text(l.t('trust_from_contacts'))),
          PopupMenuItem(value: 1, child: Text(l.t('trust_my_key'))),
        ],
        child: IgnorePointer(
          child: FloatingActionButton.extended(
            heroTag: 'trust_org',
            onPressed: () {},
            icon: const Icon(Icons.add_moderator_outlined),
            label: Text(l.t('trust_organization')),
          ),
        ),
      ),
      body: SafeArea(
        child: roots.when(
          loading: () => const SkeletonList(),
          error: (e, _) => const SizedBox.shrink(),
          data: (list) => list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_outlined, size: 48, color: outline),
                        const SizedBox(height: 12),
                        Text(l.t('no_trusted_orgs'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 18,
                                color: outline)),
                        const SizedBox(height: 6),
                        Text(l.t('no_trusted_hint'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16,
                                color: outline)),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(l.t('trusted_roots'),
                          style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ),
                    for (final r in list)
                      ListTile(
                        leading: const Icon(Icons.verified_rounded,
                            color: AppTheme.verified),
                        title: Text(r.name.isEmpty ? '—' : r.name),
                        subtitle: Text('${r.hex.substring(0, 16)}…'),
                        trailing: IconButton(
                          tooltip: l.t('remove'),
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _untrust(context, ref, r),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
