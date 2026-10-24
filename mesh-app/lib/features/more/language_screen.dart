import 'package:flutter/material.dart';

import '../../l10n/labels.dart';
import '../../state/app_scope.dart';
import '../../state/settings_controller.dart';
import '../../ui/feedback.dart';
import '../../ui/theme.dart';
import '../../ui/step_scaffold.dart';

/// Languages listed by their own names, so anyone can find theirs.
class LanguageOptions extends StatelessWidget {
  const LanguageOptions({super.key, this.onChosen});

  final VoidCallback? onChosen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = AppScope.of(context).settings;

    void choose(String? code) {
      Haptics.tick();
      settings.language = code;
      onChosen?.call();
    }

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        children: [
          ChoiceTile(
            icon: Icons.smartphone,
            title: l.languageSystem,
            selected: settings.language == null,
            onTap: () => choose(null),
          ),
          for (final MapEntry(key: code, value: name)
              in supportedLanguages.entries) ...[
            const SizedBox(height: 8),
            ChoiceTile(
              icon: Icons.translate,
              title: name,
              selected: settings.language == code,
              onTap: () => choose(code),
            ),
          ],
        ],
      ),
    );
  }
}

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).language)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomClearance(context)),
        children: const [LanguageOptions()],
      ),
    );
  }
}

Future<void> showLanguageSheet(BuildContext context) {
  Haptics.tick();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (sheet, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            AppLocalizations.of(sheet).language,
            style: Theme.of(sheet).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          LanguageOptions(onChosen: () => Navigator.pop(sheet)),
        ],
      ),
    ),
  );
}
