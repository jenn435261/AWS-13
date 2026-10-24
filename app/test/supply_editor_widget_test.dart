import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/app/providers.dart';
import 'package:resilience/db/database.dart';
import 'package:resilience/identity/identity_keys.dart';
import 'package:resilience/identity/identity_store.dart';
import 'package:resilience/l10n/strings.dart';
import 'package:resilience/state/derived_state.dart';
import 'package:resilience/ui/screens/supply_editor_screen.dart';

/// §3.2: Confirm/Save closes the editor and returns to the list. The editor is
/// pushed as a route; a successful Save pops it. We prove the route is gone
/// after Save (the sheet/screen dismisses) and the supply reached the log.
Widget _harness(AppDatabase db, GlobalKey<NavigatorState> nav) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWith((ref) {
        ref.onDispose(db.close);
        return db;
      }),
      identityProvider.overrideWith((ref) async {
        final keys = await IdentityKeys.generate();
        return DeviceIdentity(keys: keys, displayName: 'Tester');
      }),
    ],
    child: MaterialApp(
      navigatorKey: nav,
      localizationsDelegates: const [L10n.delegate],
      supportedLocales: L10n.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SupplyEditorScreen())),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('multi-select chips + Save closes the editor and logs supplies',
      (tester) async {
    final db = AppDatabase.memory();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_harness(db, nav));
    await tester.pumpAndSettle();

    // Open the editor.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    const l = L10n(Locale('en'));
    expect(find.text(l.t('add_supply')), findsOneWidget);

    // The extended item list is present (incl. a mapped extra item: Fuel).
    expect(find.text(l.t('item_fuel')), findsOneWidget);
    expect(find.text(l.t('cat_water')), findsWidgets);

    // Multi-select two items.
    await tester.tap(find.text(l.t('cat_water')).first);
    await tester.tap(find.text(l.t('item_fuel')).first);
    await tester.pump();

    // Save -> the editor route is popped (sheet/screen closes).
    await tester.tap(find.text(l.t('save_supply')));
    await tester.pumpAndSettle();

    expect(find.text(l.t('add_supply')), findsNothing,
        reason: 'editor should close on Save');
    expect(find.text('open'), findsOneWidget, reason: 'returned to the list');

    // Both items reached the signed log as their own supplies.
    final world = WorldState();
    await world.rebuild(db.eventDao);
    final titles = world.resources.values.map((r) => r.resource.title).toSet();
    expect(titles, containsAll(<String>['Water', 'Fuel']));
    expect(world.resources.length, 2);
  });

  testWidgets('Save with no item selected keeps the editor open with an error',
      (tester) async {
    final db = AppDatabase.memory();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_harness(db, nav));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    const l = L10n(Locale('en'));

    final saveBtn = find.widgetWithText(FilledButton, l.t('save_supply'));
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn, warnIfMissed: true);
    await tester.pumpAndSettle();

    // Editor stays open (Save did not close it).
    expect(find.text(l.t('add_supply')), findsOneWidget,
        reason: 'invalid Save must not close the editor');

    // The honest validation message is rendered. It sits at the bottom of the
    // scrollable form, so scroll it into view before asserting (a lazily-built
    // list does not instantiate off-screen children).
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text(l.t('supply_needs_category')), findsOneWidget);

    // Nothing reached the signed log.
    final world = WorldState();
    await world.rebuild(db.eventDao);
    expect(world.resources, isEmpty);
  });
}
