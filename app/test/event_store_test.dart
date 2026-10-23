import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/event_store.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/db/database.dart';
import 'package:resilience/db/event_dao.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';

ResourceBody _body(String title) => ResourceBody(
      resourceId: title,
      category: ResourceCategory.RESOURCE_CATEGORY_WATER,
      title: title,
      amount: AmountBand.AMOUNT_BAND_SOME,
      availability: Availability.AVAILABILITY_NOW,
      provenance: ProvenanceKind.PROVENANCE_KIND_COMMUNITY,
    );

void main() {
  late AppDatabase db;
  late EventDao dao;
  late Signer signer;
  late EventFactory factory;
  late EventStore store;
  late KeyPairData alice;
  late KeyPairData bob;

  setUp(() async {
    db = AppDatabase.memory();
    dao = db.eventDao;
    signer = Signer();
    factory = EventFactory(signer: signer);
    store = EventStore(dao: dao, factory: factory, clock: LamportClock());
    alice = await signer.generateKeyPair();
    bob = await signer.generateKeyPair();
  });

  tearDown(() async {
    await db.close();
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

  test('applying a valid event stores it; re-applying is a duplicate',
      () async {
    final clock = LamportClock();
    final e = await make(alice, clock, 'water');

    final r1 = await store.apply(e);
    expect(r1.status, ApplyStatus.applied);

    final r2 = await store.apply(e);
    expect(r2.status, ApplyStatus.duplicate);

    final fetched = await store.get(e.header.eventId);
    expect(fetched, isNotNull);
    expect(fetched!.header.eventId, equals(e.header.eventId));
  });

  test('an invalid (bad signature) event is rejected and not stored',
      () async {
    final clock = LamportClock();
    final e = await make(alice, clock, 'water');
    final tampered = e.deepCopy();
    final sig = Uint8List.fromList(tampered.signature);
    sig[0] ^= 0xFF;
    tampered.signature = sig;

    final r = await store.apply(tampered);
    expect(r.status, ApplyStatus.invalid);

    final all = await dao.allEvents();
    expect(all, isEmpty);
  });

  test('observing an event advances the store clock', () async {
    final remoteClock = LamportClock();
    remoteClock.observe(Int64(50));
    final e = await make(alice, remoteClock, 'water'); // lamport 51
    await store.apply(e);
    // The store clock should now be at least 51.
    expect(store.clock.currentAsInt, greaterThanOrEqualTo(51));
  });

  test('highWaterByAuthor and eventsByAuthorFrom return correct sets',
      () async {
    // Alice: 3 events; Bob: 2 events. Separate clocks (separate authors).
    final ac = LamportClock();
    final bc = LamportClock();
    final a1 = await make(alice, ac, 'a1');
    final a2 = await make(alice, ac, 'a2', prev: a1.header.eventId);
    final a3 = await make(alice, ac, 'a3', prev: a2.header.eventId);
    final b1 = await make(bob, bc, 'b1');
    final b2 = await make(bob, bc, 'b2', prev: b1.header.eventId);

    for (final e in [a1, a2, a3, b1, b2]) {
      expect((await store.apply(e)).status, ApplyStatus.applied);
    }

    final hw = await store.highWaterByAuthor();
    expect(hw[AuthorKey(alice.publicKey)], 3);
    expect(hw[AuthorKey(bob.publicKey)], 2);

    // Events after Alice's watermark 1 => a2, a3.
    final afterA1 = await dao.eventsByAuthorFrom(alice.publicKey, 1);
    expect(afterA1.map((e) => e.header.lamport.toInt()), [2, 3]);

    // Head by author = highest lamport.
    final head = await dao.headByAuthor(alice.publicKey);
    expect(head!.header.lamport.toInt(), 3);
  });

  test('missingFrom computes the correct diff for a peer digest', () async {
    final ac = LamportClock();
    final bc = LamportClock();
    final a1 = await make(alice, ac, 'a1');
    final a2 = await make(alice, ac, 'a2', prev: a1.header.eventId);
    final a3 = await make(alice, ac, 'a3', prev: a2.header.eventId);
    final b1 = await make(bob, bc, 'b1');

    for (final e in [a1, a2, a3, b1]) {
      await store.apply(e);
    }

    // Peer has Alice up to lamport 1 and has never seen Bob.
    final peerDigest = <AuthorKey, int>{
      AuthorKey(alice.publicKey): 1,
    };

    final missing = await store.missingFrom(peerDigest);
    final titles = missing
        .map((e) => ResourceBody.fromBuffer(e.body).title)
        .toSet();

    // Peer is missing a2, a3 (Alice > 1) and all of Bob (b1).
    expect(titles, containsAll(<String>{'a2', 'a3', 'b1'}));
    expect(titles.contains('a1'), isFalse);
  });
}
