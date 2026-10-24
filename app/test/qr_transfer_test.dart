import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/event_store.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/db/database.dart';
import 'package:resilience/db/event_dao.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/transport/qr_fountain.dart';
import 'package:resilience/transport/qr_transfer.dart';

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

  setUp(() async {
    db = AppDatabase.memory();
    dao = db.eventDao;
    signer = Signer();
    factory = EventFactory(signer: signer);
    store = EventStore(dao: dao, factory: factory, clock: LamportClock());
    alice = await signer.generateKeyPair();
  });

  tearDown(() async => db.close());

  Future<SignedEvent> make(LamportClock clock, String title,
      {List<int>? prev}) {
    return factory.buildFromMessage(
      keyPair: alice,
      clock: clock,
      type: EventType.EVENT_TYPE_RESOURCE_CREATED,
      body: _body(title),
      prevEventId: prev,
    );
  }

  Uint8List transferThroughQr(Uint8List payload) {
    // Simulate an animated QR channel with loss: encode, drop ~30%, decode.
    final enc = QrFountainEncoder(payload, blockSize: 256);
    final dec = QrFountainDecoder();
    var seed = 0;
    var drop = 0;
    while (!dec.isComplete && seed < 100000) {
      // Deterministic 30%-ish loss pattern.
      drop = (drop + 3) % 10;
      if (drop < 3) {
        seed++;
        continue;
      }
      dec.addQrString(enc.frameForSeed(seed).toQrString());
      seed++;
    }
    expect(dec.isComplete, isTrue);
    return dec.result!;
  }

  test('round-trips signed events through lossy QR and ingests them', () async {
    final clock = LamportClock();
    final events = <SignedEvent>[
      for (var i = 0; i < 5; i++) await make(clock, 'water-$i'),
    ];
    final payload = QrTransfer.encodePayload(events);

    final received = transferThroughQr(payload);
    expect(received, equals(payload));

    final result = await QrTransfer.ingest(store, received);
    expect(result.applied, 5);
    expect(result.invalid, 0);
    expect((await dao.allEvents()).length, 5);
  });

  test('re-ingesting the same QR payload is idempotent (duplicates)', () async {
    final clock = LamportClock();
    final events = <SignedEvent>[await make(clock, 'once')];
    final payload = QrTransfer.encodePayload(events);
    final first = await QrTransfer.ingest(store, payload);
    expect(first.applied, 1);
    final second = await QrTransfer.ingest(store, payload);
    expect(second.applied, 0);
    expect(second.duplicate, 1);
  });

  test('ABUSE: a forged event in the QR batch is rejected by apply', () async {
    final clock = LamportClock();
    final good = await make(clock, 'legit');

    // Forge: tamper the body of a signed event so its signature + content hash
    // no longer match. The fountain still delivers the bytes intact (it does
    // not know what they mean); EventStore.apply must reject it.
    final forged = good.deepCopy();
    forged.body = Uint8List.fromList([...forged.body, 0xde, 0xad]);

    final payload = QrTransfer.encodePayload(<SignedEvent>[good, forged]);
    final received = transferThroughQr(payload);
    final result = await QrTransfer.ingest(store, received);

    expect(result.applied, 1, reason: 'only the legit event stores');
    expect(result.invalid, 1, reason: 'the forged event is rejected');
    expect((await dao.allEvents()).length, 1);
  });

  test('garbage payload decodes to no events, stores nothing', () async {
    final result = await QrTransfer.ingest(
      store,
      Uint8List.fromList([0xff, 0xff, 0xff, 0x01]),
    );
    expect(result.total, 0);
    expect((await dao.allEvents()), isEmpty);
  });
}
