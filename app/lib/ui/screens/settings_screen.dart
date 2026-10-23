import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/strings.dart';

/// Settings: language switcher (EN/ES + extensible) and the biometric-lock
/// toggle for sensitive sections.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometric = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final current = ref.watch(localeProvider)?.languageCode ??
        Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('settings'))),
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(l.t('language'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ...L10n.supportedLocales.map((loc) {
              final code = loc.languageCode;
              return RadioListTile<String>(
                value: code,
                groupValue: current,
                onChanged: (v) {
                  ref.read(localeProvider.notifier).state = Locale(v!);
                },
                title: Text(L10n.languageName(code),
                    style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
              );
            }),
            const Divider(),
            SwitchListTile(
              value: _biometric,
              onChanged: (v) => setState(() => _biometric = v),
              secondary: const Icon(Icons.fingerprint_rounded),
              title: Text(l.t('biometric_lock'),
                  style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
