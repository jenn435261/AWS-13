import 'package:flutter/material.dart';

import '../../l10n/labels.dart';
import '../../state/app_scope.dart';
import '../../state/settings_controller.dart';
import '../../ui/feedback.dart';
import '../../ui/surfaces.dart';
import '../../ui/theme.dart';

class DisplayScreen extends StatelessWidget {
  const DisplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = AppScope.of(context).settings;
    final theme = Theme.of(context);

    Widget label(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(text, style: theme.textTheme.titleMedium),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.display)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: EdgeInsets.only(bottom: bottomClearance(context)),
          children: [
            label(l.theme),
            // A list, not a segmented row: "Automático" at 150% needs the
            // whole width, and no word should break in any language.
            GroupCard(children: [
              for (final (mode, icon, name) in [
                (ThemeMode.system, Icons.brightness_auto, l.themeAuto),
                (ThemeMode.light, Icons.light_mode_outlined, l.themeLight),
                (ThemeMode.dark, Icons.dark_mode_outlined, l.themeDark),
              ])
                Semantics(
                  inMutuallyExclusiveGroup: true,
                  selected: settings.themeMode == mode,
                  child: GroupTile(
                    icon: icon,
                    title: name,
                    trailing: settings.themeMode == mode
                        ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                        : const SizedBox.shrink(),
                    onTap: () => settings.themeMode = mode,
                  ),
                ),
            ]),
            label(l.textSize),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<double>(
                // The check would squeeze "150%" onto two lines.
                showSelectedIcon: false,
                segments: [
                  for (final scale in textScales)
                    ButtonSegment(
                      value: scale,
                      label: Text('${(scale * 100).round()}%'),
                    ),
                ],
                selected: {settings.textScale},
                onSelectionChanged: (s) {
                  Haptics.tick();
                  settings.textScale = s.first;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(l.textPreview, style: theme.textTheme.bodyLarge),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              secondary: const Icon(Icons.contrast),
              title: Text(l.highContrast),
              subtitle: Text(l.highContrastSub),
              value: settings.highContrast,
              onChanged: (v) {
                Haptics.tick();
                settings.highContrast = v;
              },
            ),
          ],
        ),
      ),
    );
  }
}
