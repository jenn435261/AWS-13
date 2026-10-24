import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../data/mesh_repository.dart';
import '../../l10n/labels.dart';
import '../../models/social.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/surfaces.dart';
import '../../ui/theme.dart';
import '../../ui/visuals.dart';

/// People and organizations, identified by keys, never phone numbers.
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([scope.repository.contacts, scope.repository.loading]),
      builder: (context, _) {
        final all = scope.repository.contacts.value;
        final loading = scope.repository.loading.value;
        List<Contact> of(ContactKind kind) => [
              for (final c in all)
                if (c.kind == kind) c,
            ]..sort((a, b) => a.name.compareTo(b.name));

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l.navContacts),
              bottom: TabBar(
                tabs: [Tab(text: l.tabPeople), Tab(text: l.tabOrganizations)],
              ),
            ),
            body: Column(
              children: [
                const _AddActions(),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ContactList(contacts: of(ContactKind.person), loading: loading),
                      _ContactList(
                        contacts: of(ContactKind.organization),
                        loading: loading,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The two main ways to add someone in person, plus the online ones tucked
/// behind one button.
class _AddActions extends StatelessWidget {
  const _AddActions();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push('/contacts/scan'),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(l.scanQr),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/contacts/qr'),
                  icon: const Icon(Icons.qr_code_2),
                  label: Text(l.myQr),
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () => _showMoreWays(context),
            icon: const Icon(Icons.expand_more),
            label: Text(l.moreWaysToAdd),
          ),
        ],
      ),
    );
  }

  static void _showMoreWays(BuildContext context) {
    final l = AppLocalizations.of(context);
    final online = AppScope.of(context).repository.network.value.internet;
    Haptics.tick();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.alternate_email),
              title: Text(l.addByUsername),
              subtitle: online ? null : Text(l.needsInternetToFind),
              enabled: online,
              onTap: () {
                Navigator.pop(sheet);
                _findDialog(context, byPhone: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: Text(l.addByPhone),
              subtitle: online ? null : Text(l.needsInternetToFind),
              enabled: online,
              onTap: () {
                Navigator.pop(sheet);
                _findDialog(context, byPhone: true);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Looks someone up online. The number only finds their public identity;
  /// it is never used as the secure identity itself (Spec section 13).
  static void _findDialog(BuildContext context, {required bool byPhone}) {
    final l = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final input = TextEditingController();

    Future<void> find(BuildContext dialog) async {
      try {
        final found = byPhone
            ? await scope.repository.findContact(phone: input.text)
            : await scope.repository.findContact(username: input.text);
        if (dialog.mounted) Navigator.pop(dialog);
        scope.feedback.toast(
          found == null ? l.notFound : l.contactAdded(found.name),
          icon: found == null ? Icons.search_off : Icons.person_add_alt,
        );
      } on NeedsInternet {
        scope.feedback.toast(l.needsInternetToFind, icon: Icons.cloud_off);
      }
    }

    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(byPhone ? l.addByPhone : l.addByUsername),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: byPhone ? TextInputType.phone : TextInputType.text,
          onSubmitted: (_) => find(dialog),
          decoration: InputDecoration(
            labelText: byPhone ? l.phoneLabel : l.usernameLabel,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l.close)),
          FilledButton(onPressed: () => find(dialog), child: Text(l.find)),
        ],
      ),
    ).whenComplete(input.dispose);
  }
}

class _ContactList extends StatelessWidget {
  const _ContactList({required this.contacts, required this.loading});

  final List<Contact> contacts;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final padding = EdgeInsets.only(bottom: bottomClearance(context));

    if (loading) {
      return Skeletonizer(
        child: ListView(
          padding: padding,
          children: [
            for (var i = 0; i < 4; i++)
              const _ContactTile(
                contact: Contact(
                  id: '0000000000000000',
                  name: 'Someone',
                  kind: ContactKind.person,
                  source: ContactSource.qr,
                ),
              ),
          ],
        ),
      );
    }
    if (contacts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l.noContacts, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(
      padding: padding,
      children: [for (final c in contacts) _ContactTile(contact: c)],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final ct = contact;
    final trusted = ct.verifiedOrganization || ct.metInPerson;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ct.kind == ContactKind.organization
          ? const IconTile(icon: Icons.apartment, color: Hues.police, size: 48)
          : Avatar(name: ct.name, size: 48),
      title: Text(ct.name),
      subtitle: Text('${l.contactSource(ct)}  ·  ${_short(ct.id)}'),
      trailing: Icon(
        trusted ? Icons.verified : Icons.help_outline,
        color: trusted ? c.primary : c.outline,
        semanticLabel: l.contactSource(ct),
      ),
      onTap: () => _showContact(context, ct),
    );
  }

  static String _short(String id) => '${id.substring(0, 4)} ${id.substring(4, 8)}';

  static void _showContact(BuildContext context, Contact contact) {
    final l = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    Haptics.tick();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(contact.name, style: Theme.of(sheet).textTheme.titleLarge),
              subtitle: Text('${l.resilienceId}: ${_grouped(contact.id)}\n${l.contactSource(contact)}'),
            ),
            if (contact.kind == ContactKind.person)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(l.messageAction),
                onTap: () {
                  Navigator.pop(sheet);
                  final channel = 'dm-${contact.name.toLowerCase()}';
                  final exists = scope.repository.channels.value.any((c) => c.id == channel);
                  context.go(exists ? '/messages/$channel' : '/messages');
                },
              ),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined),
              title: Text(l.removeContact),
              onTap: () {
                Navigator.pop(sheet);
                scope.undoable(
                  context,
                  message: l.contactRemoved(contact.name),
                  undone: l.contactAdded(contact.name),
                  icon: Icons.person_remove_outlined,
                  run: () => scope.repository.removeContact(contact.id),
                  revert: () => scope.repository.restoreContact(contact),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _grouped(String id) => [
        for (var i = 0; i < id.length; i += 4) id.substring(i, i + 4),
      ].join(' ');
}
