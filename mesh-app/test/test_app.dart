import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_app/app.dart';
import 'package:mesh_app/data/mock_mesh_repository.dart';
import 'package:mesh_app/features/contacts/scan_screen.dart';
import 'package:mesh_app/state/auth_controller.dart';
import 'package:mesh_app/state/identity.dart';
import 'package:mesh_app/state/lock_controller.dart';
import 'package:mesh_app/state/settings_controller.dart';
import 'package:mesh_app/ui/theme.dart';

/// Everything a test needs to drive the app without a device or network.
class TestApp {
  TestApp._(this.repository, this.settings);

  static Identity? _identity;

  /// Only the key pair is made on the real clock. The repository must be made
  /// in the test's own zone, or its load timers never fire under fake time.
  static Future<TestApp> create(WidgetTester tester, {String? language}) async {
    scannerCameraEnabled = false;
    final identity = _identity ??= (await tester.runAsync(Identity.generate))!;
    final settings = SettingsController(store: MemorySettingsStore());
    if (language != null) settings.language = language;
    return TestApp._(
      MockMeshRepository(
        identity: identity,
        simulateTraffic: false,
        loadDelay: Duration.zero,
        stageDelay: const Duration(milliseconds: 100),
      ),
      settings,
    );
  }

  final MockMeshRepository repository;
  final SettingsController settings;
  final auth = AuthController();
  final lock = LockController(deviceLockAvailable: false);

  /// Pumps the app at phone size and waits for the first load.
  Future<void> pump(WidgetTester tester, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MeshApp(auth: auth, repository: repository, settings: settings, lock: lock),
    );
    await settle(tester);
  }

  /// Like pumpAndSettle, but tolerates spinners that never stop.
  static Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Unmounts the app, which cancels its timers.
  static Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 7));
  }
}

/// Fails if any visible text, including text fields, is under [minFontSize].
void expectNoSmallText(WidgetTester tester, String where) {
  final small = <String>[];

  for (final element in find.byType(RichText).evaluate()) {
    final root = (element.widget as RichText).text;
    final rootSize = root.style?.fontSize ?? 14;
    root.visitChildren((span) {
      final size = span.style?.fontSize ?? rootSize;
      if (size < minFontSize && span is TextSpan && (span.text ?? '').trim().isNotEmpty) {
        small.add('"${span.text}" at ${size}px');
      }
      return true;
    });
  }
  for (final element in find.byType(EditableText).evaluate()) {
    final size = (element.widget as EditableText).style.fontSize ?? 14;
    if (size < minFontSize) small.add('text field at ${size}px');
  }

  expect(small, isEmpty, reason: 'Text under ${minFontSize}px on $where');
}
