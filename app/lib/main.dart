import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'l10n/strings.dart';
import 'ui/app_shell.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: ResilienceApp()));
}

/// Root of the Resilience Network app.
///
/// Map-first, offline-first: the UI boots immediately to the map shell and
/// loads data (resources, alerts) asynchronously in the background — the first
/// paint never blocks on disk or network. i18n (EN/ES) and the 16px-minimum
/// theme are applied app-wide.
class ResilienceApp extends ConsumerWidget {
  const ResilienceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'Resilience',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppShell(),
    );
  }
}
