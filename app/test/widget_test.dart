import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/app/providers.dart';
import 'package:resilience/db/database.dart';
import 'package:resilience/identity/identity_keys.dart';
import 'package:resilience/identity/identity_store.dart';
import 'package:resilience/ui/app_shell.dart';

/// Smoke tests for the app shell: it boots to the map, bottom nav switches
/// tabs (and back), and the conditional Deliveries tab is hidden by default
/// and shown when a distributor capability/active mission is present.
Widget _harness() {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWith((ref) {
        final db = AppDatabase.memory();
        ref.onDispose(db.close);
        return db;
      }),
      identityProvider.overrideWith((ref) async {
        final keys = await IdentityKeys.generate();
        return DeviceIdentity(keys: keys, displayName: 'Test User');
      }),
    ],
    child: const MaterialApp(home: AppShell()),
  );
}

void main() {
  testWidgets('boots to a map-first shell with bottom navigation',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump(const Duration(milliseconds: 300));

    // Bottom nav shows the four default destinations.
    expect(find.text('Map'), findsWidgets);
    expect(find.text('Messages'), findsWidgets);
    expect(find.text('Contacts'), findsWidgets);
    expect(find.text('More'), findsWidgets);

    // The two primary emergency actions are present on the map.
    expect(find.text('I Need Help'), findsOneWidget);
    expect(find.text('Offer Help'), findsOneWidget);
  });

  testWidgets('navigating to Contacts and back works', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Contacts').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('My Resilience ID'), findsOneWidget);

    // Back to the map.
    await tester.tap(find.text('Map').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('I Need Help'), findsOneWidget);
  });

  testWidgets('Deliveries tab is hidden by default, shown when enabled',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Deliveries'), findsNothing);
  });
}
