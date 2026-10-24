import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_app/ui/step_scaffold.dart';

import 'test_app.dart';

void main() {
  testWidgets('debug', (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    int mine() => app.repository.requests.value.where((r) => r.mine).length;
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/help');
    await TestApp.settle(tester);
    debugPrint('A mine=${mine()}');
    await tester.scrollUntilVisible(
      find.text('Other'),
      300,
      scrollable: find.descendant(of: find.byType(StepScaffold), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(find.text('Other'));
    await TestApp.settle(tester);
    debugPrint('B mine=${mine()}');
    await tester.ensureVisible(find.text('Add details'));
    await tester.pump();
    debugPrint('C mine=${mine()}');
    await tester.tap(find.text('Add details'));
    await TestApp.settle(tester);
    debugPrint('D mine=${mine()}');
    await tester.enterText(find.byType(TextField).first, 'my grandmother needs insulin kept cold');
    await TestApp.settle(tester);
    debugPrint('E mine=${mine()}');
    await tester.tap(find.text('Use this'));
    await TestApp.settle(tester);
    debugPrint('F mine=${mine()}');
    await TestApp.close(tester);
  });
}
