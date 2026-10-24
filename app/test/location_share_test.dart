import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/location/location_share.dart';
import 'package:resilience/location/location_state.dart';
import 'package:resilience/messaging/secure_session.dart';
import 'package:resilience/messaging/signal_keys.dart';
import 'package:resilience/state/derived_state.dart';

String hex(List<int> bytes) {
  final StringBuffer sb = StringBuffer();
  for (final int b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

GeoPoint exactPoint() => GeoPoint(
      h3Cell: Int64(0x8928308280fffff),
      approxLat: 37.33,
      approxLon: -121.88,
      exactLat: 37.335480,
      exactLon: -121.885790,
      hasExact: true,
      address: '1 Washington Sq, San Jose',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Signer signer;
  late KeyPairData aliceKp; // the sharer (author of LOCATION_* events)
  late KeyPairData bobKp; // the intended contact recipient
  late KeyPairData carolKp; // a non-recipient

  setUp(() async {
    signer = Signer();
    aliceKp = await signer.generateKeyPair();
    bobKp = await signer.generateKeyPair();
    carolKp = await signer.generateKeyPair();
  });

  // Build a 1:1 session pair sharer(Alice) -> recipient(Bob). Returns the
  // outbound session (for the sharer to encrypt) and the inbound session (for
  // the recipient to decrypt), plus the recipient store so a second message
  // stays in-ratchet.
  Future<({SecureSession outbound, SecureSession inbound})> pairAliceToBob({
    String bobName = 'bob',
  }) async {
    final aliceSignal = await SignalKeys.generate();
    final bobSignal = await SignalKeys.generate();
    final aliceStore = await aliceSignal.buildStore();
    final bobStore = await bobSignal.buildStore();
    final bobBundle =
        SignalKeys.preKeyBundleFromBody(bobSignal.toPrekeyBundleBody());

    final outbound = await SecureSession.initiate(
      localStore: aliceStore,
      remoteAddress: SignalProtocolAddress(bobName, 1),
      remoteBundle: bobBundle,
    );
    final inbound = SecureSession.forRemote(
      localStore: bobStore,
      remoteAddress: const SignalProtocolAddress('alice', 1),
    );
    return (outbound: outbound, inbound: inbound);
  }

  group('shareWithContact', () {
    test('recipient decrypts exact point; non-recipient cannot; publicPoint '
        'empty; expiresMs future; scope contact:', () async {
      final sessions = await pairAliceToBob();
      final sharer = LocationSharer(
        selfKeyPair: aliceKp,
        clock: LamportClock(),
      );

      final GeoPoint exact = exactPoint();
      final SignedEvent ev = await sharer.shareWithContact(
        RecipientIdentity(pubkey: bobKp.publicKey, session: sessions.outbound),
        exact,
        ttl: const Duration(minutes: 15),
        note: 'at the north plaza',
      );

      final LocationShareBody body = LocationShareBody.fromBuffer(ev.body);

      // Scope + guarantees.
      expect(body.scope, 'contact:${hex(bobKp.publicKey)}');
      expect(body.hasPublicPoint(), isFalse,
          reason: 'contact share must not leak a cleartext point');
      expect(body.encryptedPoint, isNotEmpty);
      expect(
        body.expiresMs.toInt(),
        greaterThan(DateTime.now().toUtc().millisecondsSinceEpoch),
      );

      // Event is well-formed + verifiable + correct type.
      expect(ev.header.type, EventType.EVENT_TYPE_LOCATION_SHARE);
      expect(await EventFactory().verifyEvent(ev), isTrue);

      // Recipient (Bob) can decrypt back to the exact GeoPoint.
      final Uint8List plain = await sessions.inbound
          .decrypt(Uint8List.fromList(body.encryptedPoint));
      final GeoPoint got = GeoPoint.fromBuffer(plain);
      expect(got.exactLat, closeTo(exact.exactLat, 1e-9));
      expect(got.exactLon, closeTo(exact.exactLon, 1e-9));
      expect(got.hasExact, isTrue);
      expect(got.address, exact.address);

      // A non-recipient (Carol) with her own unrelated session CANNOT decrypt
      // the ciphertext.
      final carolPair = await pairAliceToBob(bobName: 'carol');
      await expectLater(
        carolPair.inbound.decrypt(Uint8List.fromList(body.encryptedPoint)),
        throwsA(isA<Object>()),
      );
    });
  });

  group('broadcastPublicBeacon', () {
    test('coarseOnly: publicPoint hasExact=false, no exact coords; '
        'encryptedPoint empty', () async {
      final sharer = LocationSharer(
        selfKeyPair: aliceKp,
        clock: LamportClock(),
      );

      final SignedEvent ev = await sharer.broadcastPublicBeacon(
        exactPoint(),
        ttl: const Duration(minutes: 10),
      );
      final LocationShareBody body = LocationShareBody.fromBuffer(ev.body);

      expect(body.scope, 'public');
      expect(body.encryptedPoint, isEmpty);
      expect(body.hasPublicPoint(), isTrue);

      final GeoPoint p = body.publicPoint;
      expect(p.hasExact, isFalse);
      expect(p.hasExactLat(), isFalse);
      expect(p.hasExactLon(), isFalse);
      expect(p.address, isEmpty);
      // The coarse bucket survives.
      expect(p.hasH3Cell(), isTrue);
    });
  });

  group('ActiveShares fold', () {
    test('stop() marks a share inactive', () async {
      final sharer = LocationSharer(
        selfKeyPair: aliceKp,
        clock: LamportClock(),
      );
      final sessions = await pairAliceToBob();

      final SignedEvent share = await sharer.shareWithContact(
        RecipientIdentity(pubkey: bobKp.publicKey, session: sessions.outbound),
        exactPoint(),
        ttl: const Duration(minutes: 30),
        shareId: 'share-A',
      );

      final ActiveShares before = ActiveShares.fold([share]);
      expect(before.outgoing().map((s) => s.shareId), contains('share-A'));

      final SignedEvent stop = await sharer.stop(shareId: 'share-A');
      final ActiveShares after = ActiveShares.fold([share, stop]);
      expect(after.outgoing().map((s) => s.shareId), isNot(contains('share-A')));
    });

    test('an expired share (ttl in the past) is excluded', () async {
      // Author the share with a clock far in the past so expiresMs < now.
      final past = DateTime.utc(2000, 1, 1);
      final sharer = LocationSharer(
        selfKeyPair: aliceKp,
        clock: LamportClock(),
        now: () => past,
      );
      final sessions = await pairAliceToBob();

      final SignedEvent share = await sharer.shareWithContact(
        RecipientIdentity(pubkey: bobKp.publicKey, session: sessions.outbound),
        exactPoint(),
        ttl: const Duration(minutes: 5),
        shareId: 'stale',
      );

      final ActiveShares view = ActiveShares.fold([share]);
      expect(view.outgoing(), isEmpty);
    });
  });

  group('ActiveShares.incomingFor', () {
    test('decrypts a contact share for the right viewer only', () async {
      final sessions = await pairAliceToBob();
      final sharer = LocationSharer(
        selfKeyPair: aliceKp,
        clock: LamportClock(),
      );

      final GeoPoint exact = exactPoint();
      final SignedEvent share = await sharer.shareWithContact(
        RecipientIdentity(pubkey: bobKp.publicKey, session: sessions.outbound),
        exact,
        ttl: const Duration(minutes: 20),
        note: 'near the clinic',
      );

      final ActiveShares view = ActiveShares.fold([share]);

      // Bob (the right viewer) resolves the exact point.
      final bobSessions = ShareSessions(
        viewerPubkey: bobKp.publicKey,
        contactSessions: {hex(aliceKp.publicKey): sessions.inbound},
      );
      final List<IncomingShare> bobIncoming =
          await view.incomingFor(bobSessions);
      expect(bobIncoming, hasLength(1));
      expect(bobIncoming.first.point.exactLat, closeTo(exact.exactLat, 1e-9));
      expect(bobIncoming.first.point.exactLon, closeTo(exact.exactLon, 1e-9));
      expect(bobIncoming.first.note, 'near the clinic');
      expect(bobIncoming.first.freshness.inMinutes, greaterThan(0));

      // Carol (wrong viewer) is not the audience: nothing resolves even if she
      // somehow held a session keyed by Alice.
      final carolSessions = ShareSessions(
        viewerPubkey: carolKp.publicKey,
        contactSessions: {hex(aliceKp.publicKey): sessions.inbound},
      );
      final List<IncomingShare> carolIncoming =
          await view.incomingFor(carolSessions);
      expect(carolIncoming, isEmpty);
    });
  });

  // The WorldState fold is the authoritative read-model the UI uses. These
  // tests drive the fold's active-shares view (and its injected clock) exactly
  // as the map/list do: A shares with B for 15m, B sees A; A stops -> gone;
  // the share self-expires once the clock passes expiresMs; a non-audience
  // contact C never sees it and can never obtain the plaintext coordinate.
  group('WorldState location fold (A->B)', () {
    // Author events at a fixed wall clock so expiresMs is deterministic.
    final DateTime shareAt = DateTime.utc(2024, 1, 1, 12);
    final int shareAtMs = shareAt.millisecondsSinceEpoch;
    final int fifteenMinMs = const Duration(minutes: 15).inMilliseconds;

    Future<SignedEvent> buildShare({
      required SecureSession outbound,
      String shareId = 'A1',
    }) async {
      final sharer = LocationSharer(
        selfKeyPair: aliceKp,
        clock: LamportClock(),
        now: () => shareAt,
      );
      return sharer.shareWithContact(
        RecipientIdentity(pubkey: bobKp.publicKey, session: outbound),
        exactPoint(),
        ttl: const Duration(minutes: 15),
        note: 'at the north plaza',
        shareId: shareId,
      );
    }

    test('A shares with B for 15m: B sees it, C (non-audience) does not',
        () async {
      final sessions = await pairAliceToBob();
      final SignedEvent share = await buildShare(outbound: sessions.outbound);

      // Fold with the clock just after the share was authored (still active).
      final WorldState world =
          WorldState(clock: () => shareAtMs + 1000);
      world.rebuildFromEvents([share]);

      expect(world.locationShares, hasLength(1));
      expect(world.locationShares.first.scope,
          'contact:${hex(bobKp.publicKey)}');

      // B is the audience.
      final bobVisible =
          world.locationSharesVisibleTo(bobKp.publicKey);
      expect(bobVisible, hasLength(1));
      expect(bobVisible.first.shareId, 'A1');

      // C is NOT the audience: the fold never surfaces the share to her.
      final carolVisible =
          world.locationSharesVisibleTo(carolKp.publicKey);
      expect(carolVisible, isEmpty);

      // Even holding Alice's own share ciphertext, C cannot decrypt it: no
      // plaintext coordinate can leak to a non-audience contact.
      final carolPair = await pairAliceToBob(bobName: 'carol');
      await expectLater(
        carolPair.inbound.decrypt(
            Uint8List.fromList(world.locationShares.first.encryptedPoint)),
        throwsA(isA<Object>()),
      );

      // B, the audience, decrypts the exact point via the sharer's session.
      final clear = await sessions.inbound
          .decrypt(Uint8List.fromList(world.locationShares.first.encryptedPoint));
      final got = GeoPoint.fromBuffer(clear);
      expect(got.exactLat, closeTo(37.335480, 1e-9));
      expect(got.exactLon, closeTo(-121.885790, 1e-9));
    });

    test('A stops: the share disappears from the fold', () async {
      final sessions = await pairAliceToBob();
      final SignedEvent share = await buildShare(outbound: sessions.outbound);
      final SignedEvent stop = await LocationSharer(
        selfKeyPair: aliceKp,
        clock: LamportClock(),
        now: () => shareAt,
      ).stop(shareId: 'A1');

      final WorldState world =
          WorldState(clock: () => shareAtMs + 1000);
      world.rebuildFromEvents([share, stop]);

      expect(world.locationShares, isEmpty);
      expect(world.locationSharesVisibleTo(bobKp.publicKey), isEmpty);
    });

    test('expiry without a stop: the share disappears once the clock passes '
        'expiresMs', () async {
      final sessions = await pairAliceToBob();
      final SignedEvent share = await buildShare(outbound: sessions.outbound);

      // Active while now < expiresMs.
      final WorldState active =
          WorldState(clock: () => shareAtMs + fifteenMinMs - 1000);
      active.rebuildFromEvents([share]);
      expect(active.locationSharesVisibleTo(bobKp.publicKey), hasLength(1));

      // Advance the injected clock PAST expiresMs: gone, no stop needed.
      final WorldState expired =
          WorldState(clock: () => shareAtMs + fifteenMinMs + 1000);
      expired.rebuildFromEvents([share]);
      expect(expired.locationShares, isEmpty);
      expect(expired.locationSharesVisibleTo(bobKp.publicKey), isEmpty);
    });

    test('abuse: C cannot stop A\'s share (only the sharer can revoke)',
        () async {
      final sessions = await pairAliceToBob();
      final SignedEvent share = await buildShare(outbound: sessions.outbound);
      // Carol forges a LOCATION_STOP for Alice's shareId. Because stops fold
      // per-author, Carol's stop only affects Carol's (nonexistent) shares.
      final SignedEvent carolStop = await LocationSharer(
        selfKeyPair: carolKp,
        clock: LamportClock(),
        now: () => shareAt,
      ).stop(shareId: 'A1');

      final WorldState world =
          WorldState(clock: () => shareAtMs + 1000);
      world.rebuildFromEvents([share, carolStop]);

      // Alice's share is still active and still visible to B.
      expect(world.locationSharesVisibleTo(bobKp.publicKey), hasLength(1));
    });
  });
}
