import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_app/data/mock_mesh_repository.dart';
import 'package:mesh_app/features/shell/help_button.dart';
import 'package:mesh_app/models/help.dart';
import 'package:mesh_app/ui/step_scaffold.dart';
import 'package:mesh_app/ui/surfaces.dart';

import 'test_app.dart';

Future<void> _openDetails(WidgetTester tester) async {
  await tester.tap(find.byType(HelpButton));
  await TestApp.settle(tester);
  await tester.tap(find.text('I need help'));
  await TestApp.settle(tester);
  await tester.tap(find.text('Medicine'));
  await TestApp.settle(tester);
}

Finder _inStep(Finder matching) =>
    find.descendant(of: find.byType(StepScaffold), matching: matching);

void _setLocation(MockMeshRepository repo, LocationFix? fix) {
  final location = repo.location;
  expect(location, isA<ValueNotifier<LocationFix?>>());
  (location as ValueNotifier<LocationFix?>).value = fix;
}

void main() {
  testWidgets('step 2 asks only how urgent, with details behind an expander', (
    tester,
  ) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    await _openDetails(tester);

    expect(find.text('How urgent is it?'), findsOneWidget);
    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(_inStep(find.byIcon(Icons.check_circle)), findsOneWidget);
    expect(find.text('Add details'), findsOneWidget);
    expect(find.text('A note, and how many people'), findsOneWidget);

    // The note and the people count stay folded until asked for.
    expect(find.byType(TextField).hitTestable(), findsNothing);
    expect(find.text('How many people need help?').hitTestable(), findsNothing);
    expect(find.textContaining('Shared automatically'), findsOneWidget);

    await tester.tap(find.text('Add details'));
    await TestApp.settle(tester);
    expect(find.byKey(const ValueKey('request-note')), findsOneWidget);
    expect(find.text('How many people need help?'), findsOneWidget);
    expect(_inStep(find.text('1 person')), findsOneWidget);
    expect(_inStep(find.byIcon(Icons.add)), findsOneWidget);
    expect(_inStep(find.byIcon(Icons.remove)), findsOneWidget);

    // No GPS: the location field is the way to say where, and Send waits for it.
    _setLocation(app.repository, null);
    await TestApp.settle(tester);
    expect(
      find.text('Your location isn\'t available. Describe where you are.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('request-location')), findsOneWidget);
    expect(
      tester
          .widget<MainButton>(find.widgetWithText(MainButton, 'Send request'))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('request-location')),
      'Library, 2nd floor',
    );
    await TestApp.settle(tester);
    expect(
      tester
          .widget<MainButton>(find.widgetWithText(MainButton, 'Send request'))
          .onPressed,
      isNotNull,
    );
    await TestApp.close(tester);
  });

  testWidgets('discarding a request can be undone, then redone', (
    tester,
  ) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    await _openDetails(tester);

    await tester.tap(_inStep(find.byTooltip('Close')));
    await TestApp.settle(tester);
    expect(find.text('How urgent is it?'), findsNothing);
    expect(find.text('Request discarded'), findsOneWidget);
    expect(find.text('Offline  ·  Ready'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await TestApp.settle(tester);
    expect(find.text('How urgent is it?'), findsOneWidget);
    expect(find.text('Request restored'), findsOneWidget);
    expect(find.text('Medicine'), findsWidgets);

    await tester.tap(find.text('Redo'));
    await TestApp.settle(tester);
    expect(find.text('How urgent is it?'), findsNothing);
    expect(find.text('Request discarded'), findsOneWidget);
    await TestApp.close(tester);
  });

  testWidgets('sending a request can be undone, then redone', (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    await _openDetails(tester);

    await tester.tap(find.text('Can wait'));
    await TestApp.settle(tester);
    await tester.tap(find.widgetWithText(MainButton, 'Send request'));
    await TestApp.settle(tester);

    expect(find.text('Request sent'), findsOneWidget);
    final sent = app.repository.requests.value.where((r) => r.mine).single;
    expect(sent.urgency, Urgency.later);
    expect(sent.kind, HelpKind.medicine);

    await tester.tap(find.text('Undo'));
    await TestApp.settle(tester);
    expect(app.repository.requests.value.where((r) => r.mine), isEmpty);
    expect(find.text('Request taken back'), findsOneWidget);
    expect(find.text('How urgent is it?'), findsOneWidget);

    await tester.tap(find.text('Redo'));
    await TestApp.settle(tester);
    final again = app.repository.requests.value.where((r) => r.mine).single;
    expect(again.urgency, Urgency.later);
    expect(find.text('Request sent'), findsOneWidget);
    expect(find.text('How urgent is it?'), findsNothing);
    await TestApp.close(tester);
  });
}
