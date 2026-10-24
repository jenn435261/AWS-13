import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../router.dart';
import '../../state/app_scope.dart';
import '../../state/settings_controller.dart';
import '../../ui/surfaces.dart';
import '../../ui/visuals.dart';
import '../shell/bottom_actions.dart';

/// People to text when an SOS reaches no network. Typed in by name and
/// phone number; they stay on this phone, and erasing the phone clears them.
class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final settings = scope.settings;
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final contacts = settings.emergencyContacts;
        final full = contacts.length >= maxEmergencyContacts;

        return Scaffold(
          appBar: AppBar(title: Text(l.sosContactsTitle)),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  l.sosContactsIntro,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (contacts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                  child: Text(l.sosContactsEmpty, textAlign: TextAlign.center),
                )
              else
                GroupCard(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  children: [
                    for (final (i, contact) in contacts.indexed)
                      GroupTile(
                        icon: Icons.contact_phone_outlined,
                        hue: sosRed,
                        title: contact.name,
                        subtitle: contact.phone,
                        onTap: () => context.push(emergencyContactFormPath(index: i)),
                        trailing: IconButton(
                          tooltip: l.sosRemoveContact(contact.name),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _remove(context, i, contact),
                        ),
                      ),
                  ],
                ),
              if (full)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(l.sosContactsFull(maxEmergencyContacts)),
                ),
            ],
          ),
          bottomNavigationBar: BottomActions(
            main: MainButton(
              label: l.sosAddContact,
              icon: Icons.person_add_alt,
              onPressed: full ? null : () => context.push(emergencyContactFormPath()),
            ),
          ),
        );
      },
    );
  }

  static void _remove(BuildContext context, int index, EmergencyContact contact) {
    final scope = AppScope.of(context);
    final settings = scope.settings;
    final l = AppLocalizations.of(context);
    scope.undoable(
      context,
      message: l.sosContactRemoved(contact.name),
      undone: l.sosContactSaved(contact.name),
      icon: Icons.delete_outline,
      run: () async {
        final at = settings.emergencyContacts.indexOf(contact);
        if (at >= 0) settings.removeEmergencyContactAt(at);
      },
      revert: () async {
        if (!settings.emergencyContacts.contains(contact)) {
          settings.insertEmergencyContact(index, contact);
        }
      },
    );
  }
}

/// Adds an emergency contact, or edits the one at [index]. Its own route, so
/// Back returns to wherever it was opened: the list, or the step after an
/// SOS that reached no network.
class EmergencyContactForm extends StatefulWidget {
  const EmergencyContactForm({super.key, this.index});

  final int? index;

  @override
  State<EmergencyContactForm> createState() => _EmergencyContactFormState();
}

class _EmergencyContactFormState extends State<EmergencyContactForm> {
  late final SettingsController _settings = AppScope.of(context).settings;
  late final EmergencyContact? _editing = switch (widget.index) {
    final i? when i >= 0 && i < _settings.emergencyContacts.length =>
      _settings.emergencyContacts[i],
    _ => null,
  };
  late final _name = TextEditingController(text: _editing?.name);
  late final _phone = TextEditingController(text: _editing?.phone);

  /// Only complain about the number once the person has typed some of it.
  bool get _phoneProblem => _phone.text.trim().isNotEmpty && !isValidPhone(_phone.text);

  bool get _valid => _name.text.trim().isNotEmpty && isValidPhone(_phone.text);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final settings = _settings;
    final contact = EmergencyContact(name: _name.text.trim(), phone: _phone.text.trim());
    final before = _editing;

    if (before == null && settings.emergencyContacts.length >= maxEmergencyContacts) {
      scope.feedback.toast(l.sosContactsFull(maxEmergencyContacts), icon: Icons.error_outline);
      return;
    }
    // Found by value each time, so Undo and Redo still work after the list
    // changes.
    scope.undoable(
      context,
      message: l.sosContactSaved(contact.name),
      undone: before == null ? l.sosContactRemoved(contact.name) : l.sosContactSaved(before.name),
      icon: Icons.contact_phone_outlined,
      run: () async {
        final at = before == null ? -1 : settings.emergencyContacts.indexOf(before);
        settings.saveEmergencyContact(contact, index: at >= 0 ? at : null);
      },
      revert: () async {
        final at = settings.emergencyContacts.indexOf(contact);
        if (at < 0) return;
        if (before == null) {
          settings.removeEmergencyContactAt(at);
        } else {
          settings.saveEmergencyContact(before, index: at);
        }
      },
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_editing == null ? l.sosAddContact : l.sosEditContact)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            autofocus: _editing == null,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l.sosContactName,
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumber],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _valid ? _save() : null,
            decoration: InputDecoration(
              labelText: l.sosContactPhone,
              hintText: l.sosContactPhoneHint,
              errorText: _phoneProblem ? l.sosContactPhoneInvalid : null,
              errorMaxLines: 3,
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActions(
        main: MainButton(
          label: l.sosSaveContact,
          icon: Icons.check,
          onPressed: _valid ? _save : null,
        ),
      ),
    );
  }
}
