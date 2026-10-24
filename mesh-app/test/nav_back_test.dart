import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_app/features/shell/help_button.dart';
import 'package:mesh_app/ui/step_scaffold.dart';

import 'test_app.dart';

/// The route on top. A pushed screen from another tab pops back here.
String _path(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri.path;

Future<void> _hold(
  WidgetTester tester,
  Finder target,
  Duration duration,
) async {
  final finger = await tester.startGesture(tester.getCenter(target));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(duration);
  await tester.pump(const Duration(milliseconds: 200));
  await finger.up();
  await TestApp.settle(tester);
}

/// Tab names are often only spoken: at phone width they do not fit the bar.
Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label).hitTestable());
  await TestApp.settle(tester);
}

Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    300,
    scrollable:
        find
            .descendant(
              of: find.byType(StepScaffold),
              matching: find.byType(Scrollable),
            )
            .first,
  );
}

void main() {
  testWidgets('a screen opened from another tab pops back there', (
    tester,
  ) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);

    await _openTab(tester, 'Messages');
    expect(_path(tester), '/messages');

    // The route line lives on Messages and opens Network, which is under More.
    await tester.tap(find.text('Sends over: Resilience node'));
    await TestApp.settle(tester);
    expect(_path(tester), '/more/network');
    expect(find.text('Network status'), findsOneWidget);

    await tester.pageBack();
    await TestApp.settle(tester);
    expect(_path(tester), '/messages');
    expect(find.text('Sends over: Resilience node'), findsOneWidget);

    await _openTab(tester, 'Contacts');
    await tester.tap(find.text('Maria'));
    await TestApp.settle(tester);
    await tester.tap(find.text('Message'));
    await TestApp.settle(tester);
    expect(_path(tester), '/messages/dm-maria');

    await tester.pageBack();
    await TestApp.settle(tester);
    expect(_path(tester), '/contacts');
    expect(find.text('Scan QR'), findsOneWidget);
    await TestApp.close(tester);
  });

  testWidgets('an SOS opens over the map, and Back returns to it', (
    tester,
  ) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    expect(_path(tester), '/map');

    await _hold(tester, find.byType(HelpButton), const Duration(seconds: 2));
    expect(_path(tester), startsWith('/more/requests/sos'));
    expect(find.text('No network reached'), findsNothing);

    await tester.pageBack();
    await TestApp.settle(tester);
    expect(_path(tester), '/map');
    expect(find.text('Offline  ·  Ready'), findsOneWidget);
    await TestApp.close(tester);
  });

  testWidgets('offering a ride opens Deliveries, and Back returns', (
    tester,
  ) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);

    await tester.tap(find.byType(HelpButton));
    await TestApp.settle(tester);
    await tester.tap(find.text('I can help'));
    await TestApp.settle(tester);

    await _scrollTo(tester, 'Transportation');
    await tester.tap(find.text('Transportation'));
    await TestApp.settle(tester);
    await tester.tap(find.text('Next'));
    await TestApp.settle(tester);
    await _scrollTo(tester, 'Car');
    await tester.tap(find.text('Car'));
    await TestApp.settle(tester);
    await tester.tap(find.text('Start offering'));
    await TestApp.settle(tester);

    expect(_path(tester), '/more/deliveries');
    await tester.pageBack();
    await TestApp.settle(tester);
    expect(_path(tester), '/map');
    expect(find.text('Offline  ·  Ready'), findsOneWidget);
    await TestApp.close(tester);
  });
}
