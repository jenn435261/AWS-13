import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/db/database.dart';
import 'package:resilience/identity/contact_store.dart';
import 'package:resilience/identity/identity_card.dart';
import 'package:resilience/identity/identity_keys.dart';
import 'package:resilience/ui/components/toast.dart';

Future<IdentityCard> _card(String name) async => IdentityCard.fromIdentityKeys(
    await IdentityKeys.generate(),
    displayName: name);

void main() {
  group('ContactStore', () {
    late AppDatabase db;
    late ContactStore store;

    setUp(() {
      db = AppDatabase.memory();
      store = ContactStore(db);
    });
    tearDown(() => db.close());

    test('add, list sorted by name, dedupe, remove', () async {
      final bob = await _card('bob');
      final alice = await _card('Alice');
      expect(await store.add(bob), isTrue);
      expect(await store.add(alice), isTrue);
      expect(await store.add(bob), isFalse, reason: 'idempotent');

      final names = (await store.list()).map((c) => c.displayName).toList();
      expect(names, ['Alice', 'bob']);

      await store.remove(bob.resilienceId);
      expect((await store.list()).single.displayName, 'Alice');
    });

    test('a card survives the QR payload round trip', () async {
      final c = await _card('Round Trip');
      final back = IdentityCard.fromQrPayload(c.toQrPayload());
      expect(back, c);
      expect(back.hasConsistentResilienceId, isTrue);
    });

    test('wipeAll removes contacts and events', () async {
      await store.add(await _card('x'));
      await db.wipeAll();
      expect(await store.list(), isEmpty);
    });
  });

  testWidgets('Toast with an action still auto-dismisses', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })),
    ));
    Toast.show(ctx, 'hello', undoLabel: 'Undo', onUndo: () {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('hello'), findsOneWidget);

    // Past the 5s duration (+ exit animation) the snackbar must be gone even
    // though it carries an action.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('hello'), findsNothing);
  });
}
