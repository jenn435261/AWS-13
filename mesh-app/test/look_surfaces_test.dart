import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_app/ui/surfaces.dart';
import 'package:mesh_app/ui/theme.dart';

import 'test_app.dart';

/// Rule 14: flat colors, one plain grey shadow only where something floats,
/// no gradients, no blur.

const _mainScreens = [
  '/map',
  '/messages',
  '/messages/dm-maria',
  '/contacts',
  '/more',
  '/more/requests',
  '/more/requests/r1',
  '/more/deliveries',
  '/more/deliveries/2193',
  '/more/network',
  '/more/network/radios',
];

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
  await TestApp.settle(tester);
}

bool _grey(Color c) => c.r == c.g && c.g == c.b;

/// Everything on screen that would make it look frosted, glowing or shiny.
List<String> _shine(WidgetTester tester) {
  final found = <String>[];
  if (find.byType(BackdropFilter).evaluate().isNotEmpty) found.add('a blur (BackdropFilter)');
  if (find.byType(ImageFiltered).evaluate().isNotEmpty) found.add('a filter (ImageFiltered)');
  for (final e in find.byType(DecoratedBox).evaluate()) {
    final d = (e.widget as DecoratedBox).decoration;
    final (gradient, shadows) = switch (d) {
      BoxDecoration(:final gradient, :final boxShadow) => (gradient, boxShadow),
      ShapeDecoration(:final gradient, :final shadows) => (gradient, shadows),
      _ => (null, null),
    };
    if (gradient != null) found.add('a gradient in ${e.widget}');
    if ((shadows?.length ?? 0) > 1) found.add('a ${shadows!.length}-layer shadow');
    for (final s in shadows ?? const <BoxShadow>[]) {
      if (!_grey(s.color)) found.add('a colored shadow ${s.color}');
      if (s.blurRadius > 8) found.add('a wide glow (blur ${s.blurRadius})');
    }
  }
  return found;
}

Material _panelOf(WidgetTester tester, Finder glass) => tester.widget<Material>(
      find.descendant(of: glass, matching: find.byType(Material)).first,
    );

void main() {
  for (final dark in [false, true]) {
    testWidgets('no blur, gradient or glow on the main screens (${dark ? 'dark' : 'light'})',
        (tester) async {
      final app = await TestApp.create(tester);
      if (dark) app.settings.themeMode = ThemeMode.dark;
      await app.pump(tester);

      for (final path in _mainScreens) {
        await _go(tester, path);
        expect(_shine(tester), isEmpty, reason: path);
      }
      await TestApp.close(tester);
    });
  }

  testWidgets('a floating panel is solid, with a thin outline and one grey shadow',
      (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);

    final glass = find.byType(Glass).first;
    final panel = _panelOf(tester, glass);
    expect(panel.color!.a, 1, reason: 'panels are never see-through');
    final side = (panel.shape! as RoundedRectangleBorder).side;
    expect(side.width, 1);

    final shadow = tester.widget<DecoratedBox>(
      find.descendant(of: glass, matching: find.byType(DecoratedBox)).first,
    );
    final shadows = (shadow.decoration as BoxDecoration).boxShadow!;
    expect(shadows, hasLength(1));
    expect(_grey(shadows.single.color), isTrue);
    await TestApp.close(tester);
  });

  testWidgets('an urgent tint stays solid', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: const Glass(tint: Color(0x80FF0000), child: SizedBox(width: 40, height: 40)),
    ));
    expect(_panelOf(tester, find.byType(Glass)).color!.a, 1);
  });

  testWidgets('a panel that does not float has no shadow', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: const Glass(shadow: false, child: SizedBox(width: 40, height: 40)),
    ));
    expect(
      find.descendant(of: find.byType(Glass), matching: find.byType(DecoratedBox)),
      findsNothing,
    );
  });
}
