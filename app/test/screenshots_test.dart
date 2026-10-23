import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/app/providers.dart';
import 'package:resilience/db/database.dart';
import 'package:resilience/identity/identity_keys.dart';
import 'package:resilience/identity/identity_store.dart';
import 'package:resilience/l10n/strings.dart';
import 'package:resilience/ui/app_shell.dart';
import 'package:resilience/ui/screens/contacts_screen.dart';
import 'package:resilience/ui/screens/help_flow_screen.dart';
import 'package:resilience/ui/screens/location_share_screen.dart';
import 'package:resilience/ui/screens/messages_screen.dart';
import 'package:resilience/ui/screens/more_screen.dart';
import 'package:resilience/ui/screens/network_status_screen.dart';
import 'package:resilience/ui/screens/settings_screen.dart';
import 'package:resilience/ui/theme/app_theme.dart';

/// Renders each screen to a PNG so the UI can be reviewed screen-by-screen
/// without a device. Images are written to build/screenshots/. Runs on the
/// native test VM (no dart2js / web limitations).
void main() {
  final dir = Directory('build/screenshots');

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dir.createSync(recursive: true);
    await _loadFont('Roboto', const [
      '/projects/sandbox/.toolchain/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    ]);
    await _loadFont('MaterialIcons', const [
      '/projects/sandbox/.toolchain/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  });

  Widget wrap(Widget child, {Locale locale = const Locale('en')}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) {
          final db = AppDatabase.memory();
          ref.onDispose(db.close);
          return db;
        }),
        // Provide a resolved identity so the copyable Resilience ID renders.
        identityProvider.overrideWith((ref) async {
          final keys = await IdentityKeys.generate();
          return DeviceIdentity(keys: keys, displayName: 'Demo User');
        }),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );
  }

  final boundaryKey = GlobalKey();

  Future<Uint8List> capture() async {
    final boundary = boundaryKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final binding = TestWidgetsFlutterBinding.instance;
    final image = await binding.runAsync(() => boundary.toImage(pixelRatio: 2.0));
    if (image == null) return Uint8List(0);
    final data = await binding.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png));
    return data?.buffer.asUint8List() ?? Uint8List(0);
  }

  Future<void> shoot(WidgetTester tester, String name, Widget screen,
      {Locale locale = const Locale('en'), Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      RepaintBoundary(key: boundaryKey, child: wrap(screen, locale: locale)),
    );
    // Let async providers (identity keygen, world rebuild) resolve.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final bytes = await capture();
    if (bytes.isNotEmpty) {
      File('${dir.path}/$name.png').writeAsBytesSync(bytes);
    }
  }

  testWidgets('capture all screens', (tester) async {
    // (font loader defined at bottom)
    await shoot(tester, '01_map_home', const AppShell());
    await shoot(tester, '02_need_help', const HelpFlowScreen(isRequest: true));
    await shoot(tester, '03_offer_help', const HelpFlowScreen(isRequest: false));
    await shoot(tester, '04_messages', const MessagesScreen());
    await shoot(tester, '05_contacts', const ContactsScreen());
    await shoot(tester, '06_more', const MoreScreen());
    await shoot(tester, '07_settings', const SettingsScreen());
    await shoot(tester, '08_network_status', const NetworkStatusScreen());
    await shoot(tester, '09_location_share', const LocationShareScreen());
    // Spanish locale to prove i18n.
    await shoot(tester, '10_map_home_es', const AppShell(),
        locale: const Locale('es'));
    await shoot(tester, '11_need_help_es', const HelpFlowScreen(isRequest: true),
        locale: const Locale('es'));
  });
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final bytes = File(p).readAsBytesSync();
    loader.addFont(Future.value(bytes.buffer.asByteData()));
  }
  await loader.load();
}


