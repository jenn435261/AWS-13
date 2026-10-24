import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_app/features/requests/requests_screen.dart';
import 'package:mesh_app/features/shell/app_shell.dart';
import 'package:mesh_app/models/help.dart';
import 'package:mesh_app/ui/surfaces.dart';

import 'test_app.dart';

String _path(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri.path;

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
  await TestApp.settle(tester);
}

Finder _appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

/// Tab names are often only spoken: at phone width they do not fit the bar.
Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label).hitTestable());
  await TestApp.settle(tester);
}

void main() {
  testWidgets(
    'Contacts, Messages and My requests each have one bottom action',
    (tester) async {
      final app = await TestApp.create(tester);
      await app.pump(tester);

      await _openTab(tester, 'Contacts');
      expect(find.byType(MainButton), findsOneWidget);
      expect(find.widgetWithText(MainButton, 'Scan QR'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'My QR'), findsOneWidget);

      await tester.tap(find.widgetWithText(MainButton, 'Scan QR'));
      await TestApp.settle(tester);
      expect(_path(tester), '/contacts/scan');
      expect(find.text('Scan a QR code'), findsOneWidget);
      await tester.pageBack();
      await TestApp.settle(tester);
      expect(_path(tester), '/contacts');

      await _openTab(tester, 'Messages');
      expect(find.byType(MainButton), findsOneWidget);
      await tester.tap(find.widgetWithText(MainButton, 'New message'));
      await TestApp.settle(tester);
      expect(_path(tester), '/messages/new');
      expect(_appBarTitle('New message'), findsOneWidget);
      await tester.pageBack();
      await TestApp.settle(tester);
      expect(_path(tester), '/messages');
      expect(find.widgetWithText(MainButton, 'New message'), findsOneWidget);

      await _go(tester, '/more/requests');
      expect(find.byType(MainButton), findsOneWidget);
      expect(find.widgetWithText(MainButton, 'I can help'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(RequestTile),
          matching: find.byType(ButtonStyleButton),
        ),
        findsNothing,
      );

      await tester.tap(find.widgetWithText(MainButton, 'I can help'));
      await TestApp.settle(tester);
      expect(find.text('Supplies I can offer'), findsOneWidget);
      await tester.pageBack();
      await TestApp.settle(tester);

      await app.repository.setOffer(
        HelpOffer(kinds: {SupplyKind.water}, since: DateTime.utc(2026, 10, 24)),
      );
      await TestApp.settle(tester);
      expect(find.byType(MainButton), findsOneWidget);
      expect(
        find.widgetWithText(MainButton, 'Change what I offer'),
        findsOneWidget,
      );
      await TestApp.close(tester);
    },
  );

  testWidgets('a contact key code stays out of the list until Advanced', (
    tester,
  ) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    await _openTab(tester, 'Contacts');

    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Met in person'), findsWidgets);
    expect(find.textContaining('3a9e'), findsNothing);

    await tester.tap(find.text('Maria'));
    await TestApp.settle(tester);
    expect(find.textContaining('3a9e'), findsNothing);

    await tester.tap(find.text('Advanced'));
    await TestApp.settle(tester);
    expect(find.text('Resilience ID'), findsOneWidget);
    expect(find.text('3a9e 41c0 7b22 d5f8'), findsOneWidget);
    await TestApp.close(tester);
  });

  testWidgets('bottom bar labels are drawn at 100% and only spoken at 150%', (
    tester,
  ) async {
    final app = await TestApp.create(tester);
    // Wide enough that every English label fits at 100%, still a bottom bar.
    await app.pump(tester, size: const Size(640, 844));

    expect(find.byKey(const ValueKey('tab-label-0')), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(Icons.map)).size, 22);

    // The map card strip overflows at large text. That screen is not part of
    // this work, so only that 72px-tall card may overflow here.
    final overflows = <String>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final buffer = StringBuffer(details.exceptionAsString());
      final extra = details.informationCollector?.call();
      if (extra != null) {
        for (final node in extra) {
          buffer.writeln(node.toStringDeep());
        }
      }
      overflows.add(buffer.toString());
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    app.settings.textScale = 1.5;
    await TestApp.settle(tester);

    // Above 130% the words would crash into each other, so the icons speak.
    expect(find.byKey(const ValueKey('tab-label-0')), findsNothing);
    expect(find.byKey(const ValueKey('tab-label-1')), findsNothing);
    expect(find.text('Map'), findsNothing);
    expect(find.bySemanticsLabel('Map'), findsWidgets);
    expect(find.bySemanticsLabel('Messages'), findsWidgets);
    expect(find.bySemanticsLabel('Contacts'), findsWidgets);
    expect(find.bySemanticsLabel('More'), findsWidgets);
    expect(tester.widget<Icon>(find.byIcon(Icons.map)).size, 26);

    // On a phone, "Messages" does not fit even at 100%, so none are drawn.
    app.settings.textScale = 1.0;
    tester.view.physicalSize = const Size(390, 844) * 3;
    await TestApp.settle(tester);
    expect(find.byKey(const ValueKey('tab-label-0')), findsNothing);
    expect(find.bySemanticsLabel('Messages'), findsWidgets);
    expect(tester.widget<Icon>(find.byIcon(Icons.map)).size, 26);
    // 72px tall is the map card strip. A bottom-bar overflow would not match.
    for (final overflow in overflows) {
      expect(overflow, contains('0.0<=h<=72.0'));
    }
    await TestApp.close(tester);
  });

  testWidgets('a sideways swipe moves between tabs, except on the map', (
    tester,
  ) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);

    // The map pans with a sideways drag, so that drag must not change tabs.
    await tester.drag(find.text('Offline  ·  Ready'), const Offset(-120, 0));
    await TestApp.settle(tester);
    expect(_path(tester), '/map');
    expect(find.text('Offline  ·  Ready'), findsOneWidget);

    await _openTab(tester, 'More');

    // A short drag is not a swipe.
    await tester.drag(_appBarTitle('More'), const Offset(40, 0));
    await TestApp.settle(tester);
    expect(_path(tester), '/more');

    await tester.drag(_appBarTitle('More'), const Offset(120, 0));
    await TestApp.settle(tester);
    expect(_path(tester), '/contacts');
    expect(find.text('Scan QR'), findsOneWidget);

    await tester.drag(_appBarTitle('Contacts'), const Offset(120, 0));
    await TestApp.settle(tester);
    expect(_path(tester), '/messages');
    expect(find.text('Sends over: Resilience node'), findsOneWidget);

    await tester.drag(_appBarTitle('Messages'), const Offset(-120, 0));
    await TestApp.settle(tester);
    expect(_path(tester), '/contacts');
    expect(find.byType(TabSwipe), findsOneWidget);
    await TestApp.close(tester);
  });
}
