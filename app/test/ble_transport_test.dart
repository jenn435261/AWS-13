import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/event_store.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/db/database.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/identity/identity_keys.dart';
import 'package:resilience/sync/sync_engine.dart';
import 'package:resilience/transport/ble_chunker.dart';
import 'package:resilience/transport/ble_pairing.dart';
import 'package:resilience/transport/ble_transport.dart';
import 'package:resilience/transport/transport.dart';

/// An in-memory [BleRawChannel] pair, cross-wired like the in-memory transport,
/// with a configurable MTU. Stands in for a real GATT notify/write channel.
class FakeBleChannel extends BleRawChannel {
  FakeBleChannel._(this._out, this._in, this.mtuPayload);

  final StreamController<Uint8List> _out;
  final Stream<Uint8List> _in;
  @override
  final int mtuPayload;
  bool _open = true;

  static (FakeBleChannel, FakeBleChannel) pair({int mtuPayload = 23}) {
    final aToB = StreamController<Uint8List>.broadcast();
    final bToA = StreamController<Uint8List>.broadcast();
    final a = FakeBleChannel._(aToB, bToA.stream, mtuPayload);
    final b = FakeBleChannel._(bToA, aToB.stream, mtuPayload);
    return (a, b);
  }

  @override
  Stream<Uint8List> get packets => _in;

  @override
  bool get isOpen => _open;

  @override
  Future<void> sendPacket(Uint8List packet) async {
    if (!_out.isClosed) _out.add(Uint8List.fromList(packet));
  }

  @override
  Future<void> close() async {
    _open = false;
    if (!_out.isClosed) await _out.close();
  }
}

ResourceBody _body(String title) => ResourceBody(
      resourceId: title,
      category: ResourceCategory.RESOURCE_CATEGORY_WATER,
      title: title,
      amount: AmountBand.AMOUNT_BAND_SOME,
      availability: Availability.AVAILABILITY_NOW,
      provenance: ProvenanceKind.PROVENANCE_KIND_COMMUNITY,
    );

void main() {
  group('BleChunker MTU-aware fragmentation', () {
    test('round-trips frames at tiny and large MTUs', () {
      final rng = Random(5);
      for (final mtu in [23, 40, 185, 512]) {
        for (final size in [0, 1, 19, 20, 21, 500, 4096]) {
          final frame = Uint8List.fromList(
              List<int>.generate(size, (_) => rng.nextInt(256)));
          final payload = mtu - 3; // BLE usable payload
          final packets = BleChunker.chunk(frame, payload);
          for (final p in packets) {
            expect(p.length, lessThanOrEqualTo(payload));
          }
          final re = BleReassembler();
          Uint8List? out;
          for (final p in packets) {
            out = re.addPacket(p) ?? out;
          }
          expect(out, equals(frame),
              reason: 'mtu=$mtu size=$size failed to round-trip');
        }
      }
    });

    test('out-of-order packets still reassemble', () {
      final frame =
          Uint8List.fromList(List<int>.generate(1000, (i) => i % 256));
      final packets = BleChunker.chunk(frame, 20);
      final shuffled = packets.toList()..shuffle(Random(1));
      final re = BleReassembler();
      Uint8List? out;
      for (final p in shuffled) {
        out = re.addPacket(p) ?? out;
      }
      expect(out, equals(frame));
    });

    test('rejects an impossibly small MTU', () {
      expect(() => BleChunker.chunk(Uint8List(5), 2), throwsArgumentError);
    });
  });

  group('BlePairing 6-digit code', () {
    test('both sides derive the same code, order-independent', () {
      final a = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final b = Uint8List.fromList(List<int>.generate(32, (i) => 255 - i));
      final codeAB = BlePairing.pairingCode(a, b);
      final codeBA = BlePairing.pairingCode(b, a);
      expect(codeAB, codeBA);
      expect(codeAB.length, 6);
      expect(int.tryParse(codeAB), isNotNull);
      expect(BlePairing.codesMatch(codeAB, codeBA), isTrue);
    });

    test('a MITM substituting a key produces a mismatching code', () {
      final a = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final b = Uint8List.fromList(List<int>.generate(32, (i) => 100 + i));
      final mitm = Uint8List.fromList(List<int>.generate(32, (i) => 7 + i));

      // Alice sees (a, mitm); Bob sees (mitm, b). The two codes differ, so the
      // humans comparing them detect the attack.
      final aliceSees = BlePairing.pairingCode(a, mitm);
      final bobSees = BlePairing.pairingCode(mitm, b);
      expect(BlePairing.codesMatch(aliceSees, bobSees), isFalse);
    });

    test('derives a matching 32-byte session key on both sides', () async {
      final alice = await IdentityKeys.generate();
      final bob = await IdentityKeys.generate();

      final aliceKey = await BlePairing.deriveSessionKey(
        myKeyAgreementPrivateKey: alice.keyAgreementPrivateKey,
        myKeyAgreementPublicKey: alice.keyAgreementPublicKey,
        peerKeyAgreementPublicKey: bob.keyAgreementPublicKey,
      );
      final bobKey = await BlePairing.deriveSessionKey(
        myKeyAgreementPrivateKey: bob.keyAgreementPrivateKey,
        myKeyAgreementPublicKey: bob.keyAgreementPublicKey,
        peerKeyAgreementPublicKey: alice.keyAgreementPublicKey,
      );
      expect(aliceKey.length, 32);
      expect(aliceKey, equals(bobKey));
    });
  });

  group('BleSession encryption + sync over a fake GATT link', () {
    test('encrypted sync frames converge two stores at a tiny MTU', () async {
      // Shared session key (what pairing would have derived).
      final key = Uint8List.fromList(List<int>.generate(32, (i) => i * 3));

      final (rawA, rawB) = FakeBleChannel.pair(mtuPayload: 20);
      final sessionA = BleSession(
          peerId: 'B', raw: rawA, sessionKey: key, mtuPayload: 20);
      final sessionB = BleSession(
          peerId: 'A', raw: rawB, sessionKey: key, mtuPayload: 20);

      // Alice has 4 events, Bob has 0; after sync both hold 4.
      final dbA = AppDatabase.memory();
      final dbB = AppDatabase.memory();
      final signer = Signer();
      final factory = EventFactory(signer: signer);
      final storeA = EventStore(dao: dbA.eventDao, factory: factory);
      final storeB = EventStore(dao: dbB.eventDao, factory: factory);
      final alice = await signer.generateKeyPair();
      final clock = LamportClock();
      for (var i = 0; i < 4; i++) {
        final e = await factory.buildFromMessage(
          keyPair: alice,
          clock: clock,
          type: EventType.EVENT_TYPE_RESOURCE_CREATED,
          body: _body('r$i'),
        );
        await storeA.apply(e);
      }

      final engineA = SyncEngine(
          store: storeA, session: sessionA, idleTimeout: const Duration(milliseconds: 600));
      final engineB = SyncEngine(
          store: storeB, session: sessionB, idleTimeout: const Duration(milliseconds: 600));

      final results = await Future.wait([
        engineA.runUntilIdle(),
        engineB.runUntilIdle(),
      ]);

      expect((await dbB.eventDao.allEvents()).length, 4,
          reason: 'Bob should have received all of Alice\'s events');
      expect(results[1].applied, 4);

      await sessionA.close();
      await sessionB.close();
      await dbA.close();
      await dbB.close();
    });

    test('a packet encrypted with the wrong key is dropped', () async {
      final keyA = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final keyB = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
      final (rawA, rawB) = FakeBleChannel.pair(mtuPayload: 60);
      final sender = BleSession(
          peerId: 'B', raw: rawA, sessionKey: keyA, mtuPayload: 60);
      final receiver = BleSession(
          peerId: 'A', raw: rawB, sessionKey: keyB, mtuPayload: 60);

      final got = <Uint8List>[];
      final sub = receiver.incoming.listen(got.add);
      await sender.send(Uint8List.fromList([1, 2, 3, 4, 5]));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(got, isEmpty, reason: 'wrong-key packet must not decrypt');
      await sub.cancel();
      await sender.close();
      await receiver.close();
    });
  });

  group('BleTransport wiring over a fake link', () {
    test('connect yields a working session', () async {
      final key = Uint8List.fromList(List<int>.generate(32, (i) => 9));
      final link = _FakeBleLink(mtuPayload: 40);
      final transport = BleTransport(link: link, sessionKey: key);
      await transport.start();
      final peers = await transport.discoverPeers().first;
      expect(peers.via, TransportKind.bluetooth);
      final session = await transport.connect(peers);
      expect(session.isOpen, isTrue);
      await session.close();
      await transport.stop();
    });
  });
}

/// A fake [BleLink] that returns one discoverable peer and a loopback channel.
class _FakeBleLink extends BleLink {
  _FakeBleLink({required this.mtuPayload});
  final int mtuPayload;

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}

  @override
  Stream<DiscoveredPeer> discover() async* {
    yield const DiscoveredPeer(
        id: 'peer', displayName: 'Peer', via: TransportKind.bluetooth);
  }

  @override
  Future<BleRawChannel> connect(String peerId) async {
    final (a, _) = FakeBleChannel.pair(mtuPayload: mtuPayload);
    return a;
  }
}
