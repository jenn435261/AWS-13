import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_app/features/contacts/scan_screen.dart';
import 'package:mesh_app/models/mission.dart';
import 'package:mesh_app/state/auth_controller.dart';
import 'package:mesh_app/ui/hold_button.dart';

import 'test_app.dart';

void main() {
  testWidgets('HoldButton stops firing after a hold that ends in tap-cancel', (tester) async {
    var fired = 0;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: HoldButton(
          semanticsLabel: 'sos',
          onHeld: () => fired++,
          builder: (_, p) => const SizedBox(width: 100, height: 100),
        ),
      ),
    ));
    final c = tester.getCenter(find.byType(HoldButton));
    var g = await tester.startGesture(c);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 2200));
    expect(fired, 1);
    await g.moveBy(const Offset(0, 80)); // finger slides off -> onTapCancel
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();

    g = await tester.startGesture(c);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 2200));
    await g.up();
    await tester.pumpAndSettle();
    expect(fired, 2, reason: 'second SOS hold did nothing');
  });

  testWidgets('double tap on Confirm pickup delivers the package', (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    await app.repository.acceptMission('2193', carrier: AuthController.guest);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/more/deliveries/2193/scan');
    await TestApp.settle(tester);
    expect(find.byType(ScanScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '8192');
    await tester.pump();
    final button = find.descendant(of: find.byType(ScanScreen), matching: find.byType(FilledButton));
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await TestApp.settle(tester);
    final m = app.repository.missions.value.firstWhere((m) => m.id == '2193');
    expect(m.stage, MissionStage.inTransit, reason: 'one pickup tap moved it to ${m.stage}');
    await TestApp.close(tester);
  });

  testWidgets('lock + unlock during request flow loses the back stack', (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.push('/help');
    await TestApp.settle(tester);
    expect(router.canPop(), isTrue);
    app.lock.lock();
    await TestApp.settle(tester);
    await app.lock.unlock('x');
    await TestApp.settle(tester);
    expect(router.state.uri.toString(), '/help');
    expect(router.canPop(), isTrue, reason: 'Back from step 1 now leaves the app');
    await TestApp.close(tester);
  });

  testWidgets('a guest who opens the admin or manage link lands on More', (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    for (final path in ['/more/admin', '/more/manage']) {
      router.go(path);
      await TestApp.settle(tester);
      expect(router.state.uri.path, '/more', reason: path);
    }
    await TestApp.close(tester);
  });

  testWidgets('news never shows over the lock screen', (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    app.lock.lock();
    await TestApp.settle(tester);
    // A helper is found while locked; that alert would name the request.
    await app.repository.sendSos(from: AuthController.guest);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(MaterialBanner), findsNothing);
    expect(find.text('Mesh is locked'), findsOneWidget);
    await TestApp.close(tester);
  });
}
