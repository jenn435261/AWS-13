import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:mesh_app/app.dart';
import 'package:mesh_app/data/mock_mesh_repository.dart';
import 'package:mesh_app/data/offline_map.dart';
import 'package:mesh_app/data/offline_map_store.dart';
import 'package:mesh_app/features/contacts/scan_screen.dart';
import 'package:mesh_app/l10n/labels.dart';
import 'package:mesh_app/models/help.dart';
import 'package:mesh_app/state/auth_controller.dart';
import 'package:mesh_app/state/identity.dart';
import 'package:mesh_app/state/lock_controller.dart';
import 'package:mesh_app/state/settings_controller.dart';

import 'test_app.dart';

/// The demo network, but with a location the test decides: none at first,
/// as when GPS can't find the phone.
class NoGpsRepository extends MockMeshRepository {
  NoGpsRepository({required super.identity})
      : super(
          simulateTraffic: false,
          loadDelay: Duration.zero,
          stageDelay: const Duration(milliseconds: 100),
        );

  final fix = ValueNotifier<LocationFix?>(null);
  final setByHand = <(LatLng, String)>[];

  @override
  ValueListenable<LocationFix?> get location => fix;

  @override
  Future<void> setManualLocation(LatLng point, {String label = ''}) async {
    setByHand.add((point, label));
    fix.value = LocationFix(point, 50, source: LocationSource.manual, label: label.trim());
  }
}

/// Drives the app for map tests, with or without GPS, at any text size,
/// and with an offline map that never touches the network or the disk.
class MapTestApp {
  MapTestApp._(this.repository, this.settings);

  static Identity? _identity;

  static Future<MapTestApp> create(
    WidgetTester tester, {
    String? language,
    double textScale = 1,
    bool gps = true,
    http.Client? mapClient,
  }) async {
    scannerCameraEnabled = false;
    final identity = _identity ??= (await tester.runAsync(Identity.generate))!;
    final settings = SettingsController(store: MemorySettingsStore());
    if (language != null) settings.language = language;
    settings.textScale = textScale;
    final offline = OfflineMap(
      client: mapClient ?? MockClient((_) => Completer<http.Response>().future),
      store: MemoryOfflineMapStore(),
    );
    debugOfflineMap = offline;
    addTearDown(() => debugOfflineMap = null);
    return MapTestApp._(
      gps
          ? MockMeshRepository(
              identity: identity,
              simulateTraffic: false,
              loadDelay: Duration.zero,
              stageDelay: const Duration(milliseconds: 100),
            )
          : NoGpsRepository(identity: identity),
      settings,
    );
  }

  final MockMeshRepository repository;
  final SettingsController settings;
  final auth = AuthController();
  final lock = LockController(deviceLockAvailable: false);

  OfflineMap get offline => offlineMap;

  NoGpsRepository get noGps => repository as NoGpsRepository;

  Future<void> pump(WidgetTester tester, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MeshApp(auth: auth, repository: repository, settings: settings, lock: lock),
    );
    await TestApp.settle(tester);
  }

  /// The strings the app shows, in [language].
  static AppLocalizations strings([String language = 'en']) =>
      lookupAppLocalizations(Locale(language));

  static GoRouter router(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first));
}
