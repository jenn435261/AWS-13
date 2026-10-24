import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/providers.dart';
import '../../identity/identity_card.dart';
import '../../l10n/strings.dart';
import '../components/common.dart';
import '../components/toast.dart';
import 'qr_scan_screen.dart';

/// Contacts: people / organizations / verified. Contacts are public identity
/// cards saved on this device. A single expandable "Add contact" button at the
/// bottom holds the ways to add one (scan, my QR, enter code) so the list keeps
/// the screen.
class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final identity = ref.watch(identityProvider);
    final contacts = ref.watch(contactsProvider);
    final roots = ref.watch(trustRootsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.t('nav_contacts')),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.t('people')),
              Tab(text: l.t('organizations')),
              Tab(text: l.t('verified')),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: const _AddContactMenu(),
        body: Column(
          children: [
            identity.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonBox(height: 72),
              ),
              error: (e, _) => const SizedBox.shrink(),
              data: (id) => Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.t('my_resilience_id'),
                          style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      CopyableText(
                        value: id.resilienceId,
                        copiedMessage: l.t('copied'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: contacts.when(
                loading: () => const SkeletonList(),
                error: (e, _) => _empty(context, l, Icons.error_outline_rounded,
                    l.t('no_contacts'), ''),
                data: (all) {
                  final orgs = all
                      .where((c) => roots.isTrustedRoot(c.signingPublicKey))
                      .toList();
                  return TabBarView(
                    children: [
                      _list(context, ref, l, all),
                      _list(context, ref, l, orgs),
                      _list(context, ref, l, orgs),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, L10n l,
      List<IdentityCard> cards) {
    if (cards.isEmpty) {
      return _empty(context, l, Icons.people_outline_rounded,
          l.t('no_contacts'), l.t('no_contacts_hint'));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: cards.length,
      separatorBuilder: (_, i) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final c = cards[i];
        final initial =
            c.displayName.isEmpty ? '?' : c.displayName[0].toUpperCase();
        return ListTile(
          leading: CircleAvatar(child: Text(initial)),
          title: Text(c.displayName.isEmpty ? c.resilienceId : c.displayName),
          subtitle: Text(c.resilienceId),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _contactSheet(context, ref, l, c),
        );
      },
    );
  }

  void _contactSheet(
      BuildContext context, WidgetRef ref, L10n l, IdentityCard c) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.displayName.isEmpty ? c.resilienceId : c.displayName,
                  style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              CopyableText(value: c.resilienceId, copiedMessage: l.t('copied')),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(ctx).colorScheme.error),
                icon: const Icon(Icons.person_remove_rounded),
                label: Text(l.t('remove_contact')),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final store = ref.read(contactStoreProvider);
                  await store.remove(c.resilienceId);
                  ref.read(contactsRevisionProvider.notifier).state++;
                  if (!context.mounted) return;
                  Toast.show(context, l.t('contact_removed'),
                      undoLabel: l.t('undo'), onUndo: () async {
                    await store.add(c);
                    ref.read(contactsRevisionProvider.notifier).state++;
                  });
                },
              ),
            ],
          ),
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

/// The one bottom action. Collapsed it is a single "Add contact" button; when
/// tapped it expands upward into the three ways to add someone.
class _AddContactMenu extends ConsumerStatefulWidget {
  const _AddContactMenu();
  @override
  ConsumerState<_AddContactMenu> createState() => _AddContactMenuState();
}

class _AddContactMenuState extends ConsumerState<_AddContactMenu> {
  bool _open = false;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _open = !_open);
  }

  void _run(Future<void> Function() action) {
    setState(() => _open = false);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    Widget mini(IconData icon, String label, Future<void> Function() action) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton.extended(
          heroTag: label,
          onPressed: () => _run(action),
          icon: Icon(icon),
          label: Text(label),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open) ...[
          mini(Icons.keyboard_rounded, l.t('manual_entry'),
              () => _enterCode(context)),
          mini(Icons.qr_code_rounded, l.t('my_qr'), () => _showMyQr(context)),
          mini(Icons.qr_code_scanner_rounded, l.t('scan_qr'),
              () => _scan(context)),
        ],
        FloatingActionButton.extended(
          heroTag: 'add_contact',
          onPressed: _toggle,
          icon: Icon(_open ? Icons.close_rounded : Icons.person_add_rounded),
          label: Text(_open ? l.t('close') : l.t('add_contact')),
        ),
      ],
    );
  }

  Future<void> _scan(BuildContext context) async {
    final code = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (code == null || !context.mounted) return;
    if (code == QrScanScreen.manualEntry) return _enterCode(context);
    await _addFromCode(context, code);
  }

  Future<void> _showMyQr(BuildContext context) async {
    final l = L10n.of(context);
    final id = await ref.read(identityProvider.future);
    if (!context.mounted) return;
    final card =
        IdentityCard.fromIdentityKeys(id.keys, displayName: id.displayName);
    final payload = card.toQrPayload();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.t('share_your_code'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
              const SizedBox(height: 16),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: payload, size: 240),
              ),
              const SizedBox(height: 12),
              CopyableText(
                  value: id.resilienceId, copiedMessage: l.t('copied')),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: Text(l.t('copy_code')),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: payload));
                  if (ctx.mounted) Toast.show(ctx, l.t('copied'));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enterCode(BuildContext context) async {
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => const _EnterCodeDialog(),
    );
    if (code == null || code.trim().isEmpty || !context.mounted) return;
    await _addFromCode(context, code);
  }

  Future<void> _addFromCode(BuildContext context, String code) async {
    final l = L10n.of(context);
    try {
      final card = IdentityCard.fromQrPayload(code.trim());
      if (!card.hasConsistentResilienceId) throw const FormatException('id');
      final me = await ref.read(identityProvider.future);
      if (card.resilienceId == me.resilienceId) {
        if (context.mounted) Toast.show(context, l.t('contact_exists'));
        return;
      }
      final added = await ref.read(contactStoreProvider).add(card);
      ref.read(contactsRevisionProvider.notifier).state++;
      if (context.mounted) {
        Toast.show(
            context, added ? l.t('contact_added') : l.t('contact_exists'));
      }
    } catch (_) {
      if (context.mounted) {
        Toast.show(context, l.t('invalid_code'), urgent: true);
      }
    }
  }
}

/// Owns its TextEditingController so it is disposed only after the dialog's
/// exit animation has finished (disposing it from the caller crashes the
/// closing frame).
class _EnterCodeDialog extends StatefulWidget {
  const _EnterCodeDialog();
  @override
  State<_EnterCodeDialog> createState() => _EnterCodeDialogState();
}

class _EnterCodeDialogState extends State<_EnterCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return AlertDialog(
      title: Text(l.t('manual_entry')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        style: const TextStyle(fontFamily: 'Roboto', fontSize: 16),
        decoration: InputDecoration(hintText: l.t('paste_code')),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l.t('cancel'))),
        FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: Text(l.t('add'))),
      ],
    );
  }
}
