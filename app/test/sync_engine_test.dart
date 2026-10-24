import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/event_store.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/db/database.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/sync/sync_engine.dart';
import 'package:resilience/transport/in_memory_transport.dart';

ResourceBody _body(String title) => ResourceBody(
      resourceId: title,
      category: ResourceCategory.RESOURCE_CATEGORY_WATER,
      title: title,
      amount: AmountBand.AMOUNT_BAND_SOME,
      availability: Availability.AVAILABILITY_NOW,
      provenance: ProvenanceKind.PROVENANCE_KIND_COMMUNITY,
    );

void main() {
  late AppDatabase db1;
  late AppDatabase db2;
  late EventStore store1;
  late EventStore store2;
  late Signer signer;
  late EventFactory factory;
  late KeyPairData alice;
  late KeyPairData bob;

  // Per-author clocks so lamports are sane within an author's chain.
  late LamportClock aliceClock;
  late LamportClock bobClock;

  setUp(() async {
    db1 = AppDatabase.memory();
    db2 = AppDatabase.memory();
    signer = Signer();
    factory = EventFactory(signer: signer);
    store1 = EventStore(dao: db1.eventDao, factory: factory, clock: LamportClock());
    store2 = EventStore(dao: db2.eventDao, factory: factory, clock: LamportClock());
    alice = await signer.generateKeyPair();
    bob = await signer.generateKeyPair();
    aliceClock = LamportClock();
    bobClock = LamportClock();
  });

  tearDown(() async {
    await db1.close();
    await db2.close();
  });

  Future<SignedEvent> make(
    KeyPairData kp,
    LamportClock clock,
    String title, {
    List<int>? prev,
  }) {
    return factory.buildFromMessage(
      keyPair: kp,
      clock: clock,
      type: EventType.EVENT_TYPE_RESOURCE_CREATED,
      body: _body(title),
      prevEventId: prev,
    );
  }

  Future<Set<String>> idsOf(AppDatabase db) async {
    final ids = await db.eventDao.allEventIds();
    return ids.map(_hex).toSet();
  }

  Future<(SyncReport, SyncReport)> reconcile() async {
    final (ta, tb) = InMemoryTransport.pair();
    await ta.start();
    await tb.start();

    final engine1 = SyncEngine(store: store1, session: ta.session);
    final engine2 = SyncEngine(store: store2, session: tb.session);

    final results = await Future.wait([
      engine1.runUntilIdle(),
      engine2.runUntilIdle(),
    ]);

    await ta.stop();
    await tb.stop();
    return (results[0], results[1]);
  }

  test('two stores converge to the union of all valid events', () async {
    // Author A: 5 events in store1.
    final aEvents = <SignedEvent>[];
    List<int>? prev;
    for (int i = 0; i < 5; i++) {
      final e = await make(alice, aliceClock, 'a$i', prev: prev);
      prev = e.header.eventId;
      aEvents.add(e);
      expect((await store1.apply(e)).status, ApplyStatus.applied);
    }

    // Author B: 3 events in store2.
    final bEvents = <SignedEvent>[];
    prev = null;
    for (int i = 0; i < 3; i++) {
      final e = await make(bob, bobClock, 'b$i', prev: prev);
      prev = e.header.eventId;
      bEvents.add(e);
      expect((await store2.apply(e)).status, ApplyStatus.applied);
    }

    // Sanity: before sync each store holds only its own events.
    expect(await idsOf(db1), hasLength(5));
    expect(await idsOf(db2), hasLength(3));

    await reconcile();

    // Both stores now hold all 8 events.
    final all = <String>{
      ...aEvents.map((e) => _hex(e.header.eventId)),
      ...bEvents.map((e) => _hex(e.header.eventId)),
    };
    expect(all, hasLength(8));

    expect(await idsOf(db1), equals(all));
    expect(await idsOf(db2), equals(all));
  });

  test('incremental sync transfers only the newly added events', () async {
    // Seed and converge.
    List<int>? prev;
    for (int i = 0; i < 5; i++) {
      final e = await make(alice, aliceClock, 'a$i', prev: prev);
      prev = e.header.eventId;
      await store1.apply(e);
    }
    prev = null;
    for (int i = 0; i < 3; i++) {
      final e = await make(bob, bobClock, 'b$i', prev: prev);
      prev = e.header.eventId;
      await store2.apply(e);
    }

    await reconcile();
    expect(await idsOf(db1), hasLength(8));
    expect(await idsOf(db2), hasLength(8));

    final before2 = await idsOf(db2);

    // Add 2 more events to store1 (continue Alice's chain).
    final extra = <SignedEvent>[];
    final aliceHead = await db1.eventDao.headByAuthor(alice.publicKey);
    prev = aliceHead!.header.eventId;
    for (int i = 5; i < 7; i++) {
      final e = await make(alice, aliceClock, 'a$i', prev: prev);
      prev = e.header.eventId;
      extra.add(e);
      await store1.apply(e);
    }

    final (r1, r2) = await reconcile();

    final after2 = await idsOf(db2);
    final newlyArrived = after2.difference(before2);

    // Exactly the 2 new events reached store2.
    expect(newlyArrived, hasLength(2));
    expect(
      newlyArrived,
      equals(extra.map((e) => _hex(e.header.eventId)).toSet()),
    );
    // store2 applied exactly 2 new events this round.
    expect(r2.applied, 2);
    // store1 applied nothing new (it already had everything).
    expect(r1.applied, 0);
  });

  test('a tampered/invalid event is rejected and not stored on the peer',
      () async {
    // store1 has a valid event and a tampered one.
    final valid = await make(alice, aliceClock, 'valid');
    await store1.apply(valid);

    // Build a second valid event, then corrupt its signature. Because apply()
    // verifies, we must inject the bad event straight into the dao so it sits
    // in store1 ready to be gossiped (simulating a malicious/corrupt peer).
    final willTamper =
        await make(alice, aliceClock, 'evil', prev: valid.header.eventId);
    final tampered = willTamper.deepCopy();
    final sig = Uint8List.fromList(tampered.signature);
    sig[0] ^= 0xFF;
    tampered.signature = sig;
    // Insert the tampered event into store1's dao without verification.
    await db1.eventDao.insertEvent(tampered, valid: false);

    // store2 starts empty.
    expect(await idsOf(db2), isEmpty);

    final (r1, r2) = await reconcile();

    // store2 must hold the valid event but NOT the tampered one.
    final ids2 = await idsOf(db2);
    expect(ids2.contains(_hex(valid.header.eventId)), isTrue);
    expect(ids2.contains(_hex(tampered.header.eventId)), isFalse);

    // The tampered event was reported rejected by store2 to store1.
    // store2 received the batch, rejected the invalid event.
    expect(r2.rejected, greaterThanOrEqualTo(1));
  });
}

String _hex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
