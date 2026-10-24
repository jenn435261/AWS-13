import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_app/features/deliveries/mission_screen.dart';
import 'package:mesh_app/features/requests/request_screen.dart';
import 'package:mesh_app/features/resources/resource_sheet.dart';
import 'package:mesh_app/l10n/gen/app_localizations.dart';
import 'package:mesh_app/models/mission.dart';
import 'package:mesh_app/models/role.dart';
import 'package:mesh_app/router.dart' show missionPath;
import 'package:mesh_app/state/auth_controller.dart';
import 'package:mesh_app/state/settings_controller.dart';
import 'package:mesh_app/ui/advanced_section.dart';

import 'test_app.dart';

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first));

Future<void> _go(WidgetTester tester, String path) async {
  _router(tester).go(path);
  await TestApp.settle(tester);
}

/// Scrolls [screen]'s list until [label] shows, then taps it.
Future<void> _open(WidgetTester tester, Type screen, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    200,
    scrollable: find.descendant(of: find.byType(screen), matching: find.byType(Scrollable)).first,
  );
  await TestApp.settle(tester);
  await tester.tap(find.text(label));
  await TestApp.settle(tester);
}

/// Runs [body], ignoring layout overflow reported by the map tab. The map
/// stays built behind every other tab, and its own large-text problems
/// belong to the map screen's tests, not to the screens opened here.
Future<void> _ignoringMapOverflow(Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    if (text.contains('overflowed') && text.contains('lib/features/map/')) return;
    original?.call(details);
  };
  try {
    await body();
  } finally {
    FlutterError.onError = original;
  }
}

AppLocalizations _words(String language) => lookupAppLocalizations(Locale(language));

const _requestGone = 'This request is no longer available.';
const _deliveryGone = 'This delivery is no longer available.';
const _placeGone = 'This place is no longer on the map.';
const _sharing = 'Sharing your location until you deliver';
const _onlyWhileCarrying = 'Your location is shared only while you carry this delivery.';

void main() {
  group('links to something that is gone say what is gone', () {
    for (final (path, text, wrong) in [
      ('/more/deliveries/nope', _deliveryGone, _requestGone),
      ('/more/requests/nope', _requestGone, _deliveryGone),
      ('/more/requests/nope/card', _requestGone, _deliveryGone),
      ('/messages/nope', 'This conversation is no longer available.', 'No conversations here yet'),
    ]) {
      testWidgets(path, (tester) async {
        final app = await TestApp.create(tester);
        await app.pump(tester);
        await _go(tester, path);

        expect(find.text(text), findsOneWidget);
        expect(find.text(wrong), findsNothing);
        // There is always a way back.
        expect(find.byType(BackButton), findsOneWidget);
        await TestApp.close(tester);
      });
    }

    testWidgets('a place that was removed', (tester) async {
      final app = await TestApp.create(tester);
      await app.pump(tester);
      showResourceSheet(tester.element(find.byType(Scaffold).first), 'nope');
      await TestApp.settle(tester);

      expect(find.text(_placeGone), findsOneWidget);
      expect(find.text(_requestGone), findsNothing);
      await TestApp.close(tester);
    });
  });

  testWidgets('request details use plain words; the technical side is under Advanced',
      (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    // Maria's request has reached the server over one radio.
    await _go(tester, '/more/requests/r1');

    expect(find.text('Sent'), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);
    for (final technical in [
      'Sent over the mesh',
      'Checked by the server',
      'Passed through 1 radio',
      'AWS checked the request and saved a copy',
      'Signed history',
    ]) {
      expect(find.textContaining(technical), findsNothing, reason: technical);
    }

    // Helping signs an event, so the history has something to show.
    await tester.tap(find.text('I can help'));
    await TestApp.settle(tester);
    await tester.pump(const Duration(seconds: 7)); // the toast leaves
    await _open(tester, RequestScreen, 'Advanced');
    await TestApp.settle(tester);
    expect(find.text('Sent over the mesh'), findsOneWidget);
    expect(find.text('Passed through 1 radio'), findsOneWidget);
    expect(find.text('Checked by the server'), findsOneWidget);
    expect(find.text('Signed history'), findsOneWidget);
    await TestApp.close(tester);
  });

  testWidgets('a request still on the phone has nothing under Advanced yet', (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    await _go(tester, '/more/requests/r3');
    // Ana's request came over three radios but has not reached the server.
    await _open(tester, RequestScreen, 'Advanced');
    expect(find.text('Passed through 3 radios'), findsOneWidget);
    expect(find.text('Checked by the server'), findsNothing);
    await TestApp.close(tester);
  });

  testWidgets('the mission screen keeps its signed history under Advanced', (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    await _go(tester, missionPath('2193'));
    expect(find.byType(AdvancedSection), findsNothing, reason: 'nothing signed yet');

    await tester.tap(find.text('Accept mission'));
    await TestApp.settle(tester);
    expect(find.text('Signed history'), findsNothing);
    await tester.pump(const Duration(seconds: 7)); // the toast leaves
    await _open(tester, MissionScreen, 'Advanced');
    expect(find.text('Signed history'), findsWidgets);
    await TestApp.close(tester);
  });

  testWidgets('mission stages say where the package is; done means done', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.create(tester);
    await app.pump(tester);
    final repo = app.repository;
    await repo.acceptMission('2193', carrier: AuthController.guest);
    await _go(tester, missionPath('2193'));
    expect(find.bySemanticsLabel(RegExp(r'^Now\. Assigned to you')), findsOneWidget);

    await repo.advanceMission('2193');
    await repo.advanceMission('2193');
    await TestApp.settle(tester);
    expect(find.bySemanticsLabel(RegExp(r'^Done\. Delivered')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Now\. ')), findsNothing);

    // A package handed to the next driver is done up to the handoff only.
    await repo.acceptMission('2196', carrier: AuthController.guest);
    await repo.advanceMission('2196');
    await repo.startHandoff('2196');
    await tester.pump(const Duration(seconds: 1));
    await _go(tester, missionPath('2196'));
    expect(find.bySemanticsLabel(RegExp(r'^Done\. Awaiting handoff')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Not yet\. Delivered')), findsOneWidget);
    semantics.dispose();
    await TestApp.close(tester);
  });

  group('location is shared only during a delivery, and the screen says so', () {
    testWidgets('before accepting: one line says when it would be shared', (tester) async {
      final app = await TestApp.create(tester);
      await app.pump(tester);
      await _go(tester, missionPath('2193'));

      expect(find.text(_onlyWhileCarrying), findsOneWidget);
      expect(find.text(_sharing), findsNothing);
      expect(app.repository.sharingLocation.value, isFalse);
      await TestApp.close(tester);
    });

    testWidgets('while carrying: the notice shows, and goes once given back', (tester) async {
      final app = await TestApp.create(tester);
      await app.pump(tester);
      await _go(tester, missionPath('2193'));

      await tester.tap(find.text('Accept mission'));
      await TestApp.settle(tester);
      expect(app.repository.sharingLocation.value, isTrue);
      expect(find.text(_sharing), findsOneWidget);
      expect(find.byIcon(Icons.share_location), findsOneWidget);
      expect(find.text(_onlyWhileCarrying), findsNothing);

      await tester.tap(find.text('Undo'));
      await TestApp.settle(tester);
      expect(app.repository.sharingLocation.value, isFalse);
      expect(find.text(_sharing), findsNothing);
      await TestApp.close(tester);
    });

    testWidgets('after delivering: nothing about location', (tester) async {
      final app = await TestApp.create(tester);
      await app.pump(tester);
      await app.repository.acceptMission('2193', carrier: AuthController.guest);
      await _go(tester, missionPath('2193'));
      expect(find.text(_sharing), findsOneWidget);

      await app.repository.advanceMission('2193');
      await TestApp.settle(tester);
      expect(find.text(_sharing), findsOneWidget, reason: 'still carrying after pickup');

      await app.repository.advanceMission('2193');
      await TestApp.settle(tester);
      expect(
        app.repository.missions.value.firstWhere((m) => m.id == '2193').stage,
        MissionStage.delivered,
      );
      expect(find.text(_sharing), findsNothing);
      expect(find.text(_onlyWhileCarrying), findsNothing);
      await TestApp.close(tester);
    });

    testWidgets('another mission never says this phone is sharing', (tester) async {
      final app = await TestApp.create(tester);
      await app.pump(tester);
      await app.repository.acceptMission('2193', carrier: AuthController.guest);
      await _go(tester, missionPath('2196'));

      expect(app.repository.sharingLocation.value, isTrue);
      expect(find.byType(SharingLocationNotice), findsNothing);
      await TestApp.close(tester);
    });

    testWidgets('the notice is translated', (tester) async {
      final app = await TestApp.create(tester, language: 'vi');
      await app.pump(tester);
      await app.repository.acceptMission('2193', carrier: AuthController.guest);
      await _go(tester, missionPath('2193'));
      expect(find.text('Đang chia sẻ vị trí của bạn cho đến khi giao xong'), findsOneWidget);
      await TestApp.close(tester);
    });
  });

  group('my screens at 150% text in Vietnamese', () {
    // Any overflow fails the test on its own; these also check tap targets
    // and that every tappable thing has a spoken label.
    final paths = [
      '/more/deliveries',
      '/more/deliveries/2193',
      '/more/requests/r1',
      '/more/requests/r1/card',
      '/more/network/radios',
      '/messages/dm-maria',
      '/messages/nope',
      '/more/organizations',
      '/more/account',
      '/more/language',
      '/more/manage',
      '/more/admin',
    ];

    for (final path in paths) {
      testWidgets(path, (tester) async {
        final semantics = tester.ensureSemantics();
        await _ignoringMapOverflow(() async {
          final app = await TestApp.create(tester, language: 'vi');
          app.settings.textScale = 1.5;
          await app.auth.signIn(name: 'Avery', role: Role.admin);
          await app.pump(tester, size: const Size(360, 740));
          await _go(tester, path);

          expectNoSmallText(tester, '$path (vi, 150%)');
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await TestApp.close(tester);
        });
        semantics.dispose();
      });
    }

    testWidgets('a carried delivery with its notice', (tester) async {
      final semantics = tester.ensureSemantics();
      await _ignoringMapOverflow(() async {
        final app = await TestApp.create(tester, language: 'vi');
        app.settings.textScale = 1.5;
        await app.pump(tester, size: const Size(360, 740));
        await app.repository.acceptMission('2193', carrier: AuthController.guest);
        await _go(tester, missionPath('2193'));

        expect(find.byType(SharingLocationNotice), findsOneWidget);
        // The two actions stack so neither label is cut.
        final pickup = tester.getRect(find.text('Xác nhận đã nhận hàng'));
        final code = tester.getRect(find.text('Mã kiện hàng'));
        expect(pickup.top, greaterThan(code.bottom));
        expectNoSmallText(tester, 'carried mission (vi, 150%)');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await TestApp.close(tester);
      });
      semantics.dispose();
    });

    testWidgets('the lock screen', (tester) async {
      await _ignoringMapOverflow(() async {
        final app = await TestApp.create(tester, language: 'vi');
        app.settings.textScale = 1.5;
        await app.pump(tester, size: const Size(360, 740));
        app.lock.lock();
        await TestApp.settle(tester);
        expectNoSmallText(tester, 'lock (vi, 150%)');
        await TestApp.close(tester);
      });
    });

    testWidgets('a place sheet', (tester) async {
      final semantics = tester.ensureSemantics();
      await _ignoringMapOverflow(() async {
        final app = await TestApp.create(tester, language: 'vi');
        app.settings.textScale = 1.5;
        await app.pump(tester, size: const Size(360, 740));
        showResourceSheet(tester.element(find.byType(Scaffold).first), 'w1');
        await TestApp.settle(tester);
        expectNoSmallText(tester, 'resource sheet (vi, 150%)');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await TestApp.close(tester);
      });
      semantics.dispose();
    });
  });

  for (final language in supportedLanguages.keys) {
    testWidgets('no text under 16px in the new states ($language)', (tester) async {
      final app = await TestApp.create(tester, language: language);
      await app.pump(tester, size: const Size(360, 740));
      for (final path in ['/more/deliveries/nope', '/more/requests/nope', '/messages/nope']) {
        await _go(tester, path);
        expectNoSmallText(tester, '$path ($language)');
      }

      await _go(tester, '/more/requests/r1');
      await _open(tester, RequestScreen, _words(language).lookAdvanced);
      expectNoSmallText(tester, 'request Advanced ($language)');

      await app.repository.acceptMission('2193', carrier: AuthController.guest);
      await _go(tester, missionPath('2193'));
      expect(find.byType(SharingLocationNotice), findsOneWidget);
      expectNoSmallText(tester, 'carried mission ($language)');
      await TestApp.close(tester);
    });
  }
}
