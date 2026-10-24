import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/core/canonical.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/hashing.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';

/// Builds a representative resource body for use as an event payload.
ResourceBody _resourceBody({String title = 'Water available'}) {
  return ResourceBody(
    resourceId: 'r-1',
    category: ResourceCategory.RESOURCE_CATEGORY_WATER,
    title: title,
    notes: 'approx location',
    amount: AmountBand.AMOUNT_BAND_PLENTY,
    availability: Availability.AVAILABILITY_NOW,
    provenance: ProvenanceKind.PROVENANCE_KIND_COMMUNITY,
  );
}

void main() {
  late Signer signer;
  late EventFactory factory;
  late KeyPairData alice;

  setUp(() async {
    signer = Signer();
    factory = EventFactory(signer: signer);
    alice = await signer.generateKeyPair();
  });

  group('hashing', () {
    test('blake2b256 produces a stable 32-byte digest', () {
      final a = blake2b256(utf8Bytes('hello'));
      final b = blake2b256(utf8Bytes('hello'));
      final c = blake2b256(utf8Bytes('world'));
      expect(a.length, blake2bDigestLengthBytes);
      expect(a, equals(b)); // deterministic
      expect(a, isNot(equals(c))); // sensitive to input
    });
  });

  group('canonical serialization', () {
    test('is deterministic across repeated serialization', () {
      final body = _resourceBody();
      final b1 = canonicalBytes(body);
      final b2 = canonicalBytes(body);
      expect(b1, equals(b2));
    });

    test('hashPreimage excludes event_id but signaturePreimage includes it',
        () {
      final header = EventHeader(
        type: EventType.EVENT_TYPE_RESOURCE_CREATED,
        authorPubkey: alice.publicKey,
        lamport: Int64(1),
      );
      final body = canonicalBytes(_resourceBody());
      final preNoId = hashPreimage(header, body);
      header.eventId = blake2b256(preNoId);
      final preWithId = signaturePreimage(header, body);
      // Signature preimage must differ (it now contains the id).
      expect(preWithId, isNot(equals(preNoId)));
    });
  });

  group('event factory', () {
    test('builds a fully-formed, verifiable event', () async {
      final clock = LamportClock();
      final event = await factory.buildFromMessage(
        keyPair: alice,
        clock: clock,
        type: EventType.EVENT_TYPE_RESOURCE_CREATED,
        body: _resourceBody(),
      );

      expect(event.hasHeader(), isTrue);
      expect(event.header.type, EventType.EVENT_TYPE_RESOURCE_CREATED);
      expect(event.header.authorPubkey, equals(alice.publicKey));
      expect(event.header.lamport, Int64(1));
      expect(event.header.eventId.length, blake2bDigestLengthBytes);
      expect(event.signature.length, 64);

      expect(await factory.verifyEvent(event), isTrue);
    });

    test('event_id equals blake2b256(canonicalHeaderNoId || body)', () async {
      final clock = LamportClock();
      final event = await factory.buildFromMessage(
        keyPair: alice,
        clock: clock,
        type: EventType.EVENT_TYPE_RESOURCE_CREATED,
        body: _resourceBody(),
      );
      final recomputed =
          blake2b256(hashPreimage(event.header, event.body));
      expect(Uint8List.fromList(event.header.eventId), equals(recomputed));
    });

    test('tampering with the body fails verification', () async {
      final clock = LamportClock();
      final event = await factory.buildFromMessage(
        keyPair: alice,
        clock: clock,
        type: EventType.EVENT_TYPE_RESOURCE_CREATED,
        body: _resourceBody(),
      );
      // Flip a byte in the body.
      final tampered = event.deepCopy();
      final body = Uint8List.fromList(tampered.body);
      body[0] = body[0] ^ 0xFF;
      tampered.body = body;
      expect(await factory.verifyEvent(tampered), isFalse);
    });

    test('tampering with the signature fails verification', () async {
      final clock = LamportClock();
      final event = await factory.buildFromMessage(
        keyPair: alice,
        clock: clock,
        type: EventType.EVENT_TYPE_RESOURCE_CREATED,
        body: _resourceBody(),
      );
      final tampered = event.deepCopy();
      final sig = Uint8List.fromList(tampered.signature);
      sig[0] = sig[0] ^ 0xFF;
      tampered.signature = sig;
      expect(await factory.verifyEvent(tampered), isFalse);
    });

    test('an event signed by a different key fails verification', () async {
      final clock = LamportClock();
      final mallory = await signer.generateKeyPair();
      final event = await factory.buildFromMessage(
        keyPair: alice,
        clock: clock,
        type: EventType.EVENT_TYPE_RESOURCE_CREATED,
        body: _resourceBody(),
      );
      // Replace the author pubkey with Mallory's but keep Alice's signature.
      final tampered = event.deepCopy();
      tampered.header.authorPubkey = mallory.publicKey;
      // event_id now no longer matches (author is in the header) -> invalid.
      expect(await factory.verifyEvent(tampered), isFalse);
    });

    test('unspecified event type is rejected at build time', () async {
      final clock = LamportClock();
      expect(
        () => factory.buildFromMessage(
          keyPair: alice,
          clock: clock,
          type: EventType.EVENT_TYPE_UNSPECIFIED,
          body: _resourceBody(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('prev_event_id chains events from the same author', () async {
      final clock = LamportClock();
      final e1 = await factory.buildFromMessage(
        keyPair: alice,
        clock: clock,
        type: EventType.EVENT_TYPE_RESOURCE_CREATED,
        body: _resourceBody(title: 'first'),
      );
      final e2 = await factory.buildFromMessage(
        keyPair: alice,
        clock: clock,
        type: EventType.EVENT_TYPE_RESOURCE_UPDATED,
        body: _resourceBody(title: 'second'),
        prevEventId: e1.header.eventId,
      );
      expect(e2.header.lamport, Int64(2));
      expect(Uint8List.fromList(e2.header.prevEventId),
          equals(Uint8List.fromList(e1.header.eventId)));
      expect(await factory.verifyEvent(e2), isTrue);
    });
  });

  group('lamport clock', () {
    test('tick is monotonic', () {
      final c = LamportClock();
      expect(c.tick(), Int64(1));
      expect(c.tick(), Int64(2));
      expect(c.tick(), Int64(3));
    });

    test('observe raises the counter to max(current, seen)', () {
      final c = LamportClock();
      c.tick(); // 1
      c.observe(Int64(10)); // jump ahead
      expect(c.tick(), Int64(11));
      c.observe(Int64(5)); // lower, no effect
      expect(c.tick(), Int64(12));
    });

    test('is restorable from a persisted value', () {
      final c = LamportClock.fromInt(42);
      expect(c.current, Int64(42));
      expect(c.tick(), Int64(43));
      // Hard-set via load().
      c.load(Int64(100));
      expect(c.tick(), Int64(101));
    });
  });
}

/// Small helper: UTF-8 bytes without importing dart:convert in every test.
Uint8List utf8Bytes(String s) =>
    Uint8List.fromList(s.codeUnits);
