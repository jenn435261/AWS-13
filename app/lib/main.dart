import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'app/providers.dart';
import 'l10n/strings.dart';
import 'ui/app_shell.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(
    overrides: await _webOverrides(),
    child: const ResilienceApp(),
  ));
}

/// On web the bundle is served by the cloud API, so talk to our own origin and
/// take the client key from /app-config.json. Any failure (offline, static
/// host) leaves the defaults, i.e. AI falls back to local rules.
Future<List<Override>> _webOverrides() async {
  if (!kIsWeb) return const [];
  final origin = Uri.base.origin;
  try {
    final r = await http
        .get(Uri.parse('$origin/app-config.json'))
        .timeout(const Duration(seconds: 4));
    if (r.statusCode != 200) return const [];
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final base = (j['baseUrl'] as String?)?.isNotEmpty == true
        ? j['baseUrl'] as String
        : origin;
    return [
      cloudBaseUrlProvider.overrideWithValue(base),
      cloudApiKeyProvider.overrideWithValue((j['apiKey'] as String?) ?? ''),
    ];
  } catch (_) {
    return const [];
  }
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
