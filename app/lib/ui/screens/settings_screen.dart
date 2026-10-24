import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/settings_store.dart';
import '../../l10n/strings.dart';
import '../components/toast.dart';

/// Settings: language, feedback + privacy toggles, and an optional Identity
/// profile.
///
/// Honesty + privacy: the Identity fields are free text and never verified
/// (they grant no badge and never touch provenance). Anonymous is the default —
/// the shared QR carries no name unless "Include name in my QR" is on. The
/// "Require unlock" toggle only stores the *preference*; the unlock state is
/// never persisted.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  final _orgRole = TextEditingController();
  final _contact = TextEditingController();
  bool _loadedFields = false;

  @override
  void dispose() {
    _name.dispose();
    _orgRole.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _patch(AppSettings current, AppSettings next) async {
    await updateSettings(ref, next);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final current = ref.watch(localeProvider)?.languageCode ??
        Localizations.localeOf(context).languageCode;
    final settings = ref.watch(settingsProvider).valueOrNull;

    // Seed the identity text fields once from the loaded settings.
    if (settings != null && !_loadedFields) {
      _name.text = settings.displayName;
      _orgRole.text = settings.orgRole;
      _contact.text = settings.contactNote;
      _loadedFields = true;
    }
    final s = settings ?? const AppSettings();
    const headerStyle = TextStyle(
        fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w700);
    const bodyStyle = TextStyle(fontFamily: 'Roboto', fontSize: 16);

    return Scaffold(
      appBar: AppBar(title: Text(l.t('settings'))),
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(l.t('language'), style: headerStyle),
            ),
            RadioGroup<String>(
              groupValue: current,
              onChanged: (v) {
                if (v != null) {
                  ref.read(localeProvider.notifier).state = Locale(v);
                }
              },
              child: Column(
                children: L10n.supportedLocales.map((loc) {
                  final code = loc.languageCode;
                  return RadioListTile<String>(
                    value: code,
                    title: Text(L10n.languageName(code), style: bodyStyle),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            // --- Feedback -----------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(l.t('feedback'), style: headerStyle),
            ),
            SwitchListTile(
              value: s.hapticsEnabled,
              onChanged: (v) =>
                  _patch(s, s.copyWith(hapticsEnabled: v)),
              secondary: const Icon(Icons.vibration_rounded),
              title: Text(l.t('haptic_feedback'), style: bodyStyle),
              subtitle: Text(l.t('haptic_feedback_hint'),
                  style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
            ),
            const Divider(),
            // --- Privacy / unlock --------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(l.t('privacy'), style: headerStyle),
            ),
            SwitchListTile(
              value: s.requireUnlock,
              onChanged: (v) => _patch(s, s.copyWith(requireUnlock: v)),
              secondary: const Icon(Icons.fingerprint_rounded),
              title: Text(l.t('require_unlock'), style: bodyStyle),
              subtitle: Text(l.t('require_unlock_hint'),
                  style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
            ),
            const Divider(),
            // --- Identity -----------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(l.t('identity'), style: headerStyle),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(l.t('identity_hint'),
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.outline)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _name,
                style: bodyStyle,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                    labelText: l.t('display_name_optional'),
                    hintText: l.t('display_name_hint')),
                onChanged: (v) => _patch(s, s.copyWith(displayName: v.trim())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _orgRole,
                style: bodyStyle,
                decoration: InputDecoration(
                    labelText: l.t('org_role_optional'),
                    hintText: l.t('org_role_hint')),
                onChanged: (v) => _patch(s, s.copyWith(orgRole: v.trim())),
              ),
            ),
            // Honest note: an org/role here is self-asserted and never verified.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(l.t('org_role_not_verified'),
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.outline)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _contact,
                style: bodyStyle,
                decoration: InputDecoration(
                    labelText: l.t('contact_note_optional'),
                    hintText: l.t('contact_note_hint')),
                onChanged: (v) => _patch(s, s.copyWith(contactNote: v.trim())),
              ),
            ),
            SwitchListTile(
              value: s.includeNameInQr,
              onChanged: (v) {
                _patch(s, s.copyWith(includeNameInQr: v));
                if (v && _name.text.trim().isEmpty) {
                  Toast.show(context, l.t('include_name_needs_name'));
                }
              },
              secondary: const Icon(Icons.badge_rounded),
              title: Text(l.t('include_name_in_qr'), style: bodyStyle),
              subtitle: Text(l.t('include_name_hint'),
                  style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
