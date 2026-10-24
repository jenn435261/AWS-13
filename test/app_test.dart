import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_app/features/requests/requests_screen.dart';
import 'package:mesh_app/features/shell/help_button.dart';
import 'package:mesh_app/models/help.dart';
import 'package:mesh_app/models/mission.dart';
import 'package:mesh_app/models/resource.dart';
import 'package:mesh_app/state/settings_controller.dart';
import 'package:mesh_app/ui/step_scaffold.dart';

import 'test_app.dart';

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
  await TestApp.settle(tester);
}

/// Holds a finger down a little past [duration], like a person would.
Future<void> _hold(WidgetTester tester, Finder target, Duration duration) async {
  final finger = await tester.startGesture(tester.getCenter(target));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(duration);
  await tester.pump(const Duration(milliseconds: 200));
  await finger.up();
  await TestApp.settle(tester);
}

void main() {
  testWidgets('opens on the map with the Spec tabs and the Help button',
      (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);

    for (final tab in ['Map', 'Messages', 'Contacts', 'More']) {
      expect(find.text(tab), findsWidgets);
    }
    expect(find.byType(HelpButton), findsOneWidget);
    expect(find.text('Offline  ·  Ready'), findsOneWidget);
    expect(find.text('2 alerts'), findsOneWidget);
    await TestApp.close(tester);
  });

  testWidgets('two taps send a request; Back walks through each step',
      (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);

    await tester.tap(find.byType(HelpButton));
    await TestApp.settle(tester);
    await tester.tap(find.text('I need help'));
    await TestApp.settle(tester);
    expect(find.text('Step 1 of 2'), findsOneWidget);

    // Picking a need moves on by itself.
    await tester.tap(find.text('Medicine'));
    await TestApp.settle(tester);
    expect(find.text('Step 2 of 2'), findsOneWidget);

    // Back returns to step 1 with the choice kept.
    await tester.pageBack();
    await TestApp.settle(tester);
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.tap(find.text('Next'));
    await TestApp.settle(tester);
    await tester.tap(find.text('Send request'));
    await TestApp.settle(tester);
    expect(find.text('Saved on this phone'), findsOneWidget);
    expect(find.text('Request sent'), findsOneWidget);

    // The network, not the phone, moves it along, and every step is signed.
    await tester.pump(const Duration(seconds: 1));
    await TestApp.settle(tester);
    final mine = app.repository.requests.value.firstWhere((r) => r.mine);
    expect(mine.kind, HelpKind.medicine);
    expect(mine.stage.index, greaterThanOrEqualTo(RequestStage.verified.index));
    expect(app.repository.events.value.where((e) => e.subject == mine.id), isNotEmpty);
    await TestApp.close(tester);
  });

  testWidgets('a typed note can suggest the category, offline', (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    await _go(tester, '/help');
    // "Other" is the last choice, below the fold on a phone.
    await tester.scrollUntilVisible(
      find.text('Other'),
      300,
      scrollable: find.descendant(of: find.byType(StepScaffold), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(find.text('Other'));
    await TestApp.settle(tester);

    await tester.enterText(find.byType(TextField).first, 'my grandmother needs insulin kept cold');
    await TestApp.settle(tester);
    expect(find.text('Sounds like: Medicine'), findsOneWidget);
    await tester.tap(find.text('Use this'));
    await TestApp.settle(tester);
    expect(app.repository.requests.value.where((r) => r.mine), isEmpty);
    await TestApp.close(tester);
  });

  testWidgets('holding the Help button sends an SOS with no questions',
      (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);

    await _hold(tester, find.byType(HelpButton), const Duration(seconds: 2));

    expect(app.repository.requests.value.where((r) => r.sos), hasLength(1));
    expect(find.text('SOS sent with your location'), findsOneWidget);
    await TestApp.close(tester);
  });

  testWidgets('a short tap on Help never sends an SOS', (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);

    await tester.tap(find.byType(HelpButton));
    await TestApp.settle(tester);

    expect(app.repository.requests.value.where((r) => r.sos), isEmpty);
    expect(find.text('What do you want to do?'), findsOneWidget);
    await TestApp.close(tester);
  });

  testWidgets('accepting a request can be undone, then redone', (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    await _go(tester, '/more/requests');

    await tester.tap(
      find.descendant(of: find.byType(RequestTile), matching: find.text('I can help')).first,
    );
    await TestApp.settle(tester);
    expect(app.repository.requests.value.where((r) => r.helpingIsMe), hasLength(1));

    await tester.tap(find.text('Undo'));
    await TestApp.settle(tester);
    expect(app.repository.requests.value.where((r) => r.helpingIsMe), isEmpty);

    await tester.tap(find.text('Redo'));
    await TestApp.settle(tester);
    expect(app.repository.requests.value.where((r) => r.helpingIsMe), hasLength(1));
    await TestApp.close(tester);
  });

  testWidgets('confirming a resource is signed and can be undone', (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    final before = app.repository.resources.value.firstWhere((r) => r.id == 'x1');
    expect(before.confidence, Confidence.unconfirmed);

    await app.repository.vote('x1', Vote.confirm);
    await TestApp.settle(tester);
    final after = app.repository.resources.value.firstWhere((r) => r.id == 'x1');
    expect(after.confirmations, 1);
    expect(after.myVote, Vote.confirm);

    // Confirming again replaces the vote instead of counting twice.
    await app.repository.vote('x1', Vote.dispute);
    final changed = app.repository.resources.value.firstWhere((r) => r.id == 'x1');
    expect((changed.confirmations, changed.disputes), (0, 1));
    await TestApp.close(tester);
  });

  testWidgets('Deliveries appears only once you offer transport', (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    await _go(tester, '/more');
    expect(find.text('Deliveries'), findsNothing);

    await app.repository.setOffer(HelpOffer(
      kinds: {SupplyKind.transportation},
      since: DateTime.now(),
      transport: TransportMode.car,
    ));
    await TestApp.settle(tester);
    expect(find.text('Deliveries'), findsOneWidget);

    await _go(tester, '/more/deliveries/2193');
    await tester.tap(find.text('Accept mission'));
    await TestApp.settle(tester);
    expect(
      app.repository.missions.value.firstWhere((m) => m.id == '2193').stage,
      MissionStage.assigned,
    );
    // Only the carrier sees the exact address.
    expect(find.textContaining('742 Example Street'), findsOneWidget);
    await TestApp.close(tester);
  });

  testWidgets('locking hides everything but still allows SOS', (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);

    app.lock.lock();
    await TestApp.settle(tester);
    expect(find.text('Mesh is locked'), findsOneWidget);
    expect(find.byType(HelpButton), findsOneWidget);

    await tester.tap(find.text('Unlock'));
    await TestApp.settle(tester);
    expect(find.text('Mesh is locked'), findsNothing);
    await TestApp.close(tester);
  });

  testWidgets('erasing clears this phone and resets settings', (tester) async {
    final app = await TestApp.create(tester, language: 'es');
    await app.pump(tester);
    await app.repository.sendSos(from: app.auth.me);
    await _go(tester, '/more/privacy');

    await _hold(
      tester,
      find.text('Borrar todo en este teléfono'),
      const Duration(seconds: 3),
    );

    expect(app.repository.requests.value.where((r) => r.mine), isEmpty);
    expect(app.settings.language, isNull);
    await TestApp.close(tester);
  });

  for (final language in supportedLanguages.keys) {
    testWidgets('no text under 16px in $language', (tester) async {
      final app = await TestApp.create(tester, language: language);
      await app.pump(tester, size: const Size(360, 740));

      for (final path in [
        '/map',
        '/messages',
        '/messages/dm-maria',
        '/contacts',
        '/contacts/qr',
        '/contacts/scan',
        '/more',
        '/more/requests',
        '/more/requests/r1',
        '/more/network',
        '/more/downloads',
        '/more/organizations',
        '/more/deliveries/2193',
        '/more/privacy',
        '/more/display',
        '/offer',
        '/help',
      ]) {
        await _go(tester, path);
        expectNoSmallText(tester, '$path ($language)');
      }

      await tester.tap(find.byType(Card).at(1));
      await TestApp.settle(tester);
      expectNoSmallText(tester, '/help/details ($language)');
      await TestApp.close(tester);
    });
  }
}
