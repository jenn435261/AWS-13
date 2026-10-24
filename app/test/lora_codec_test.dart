import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/transport/lora_codec.dart';
import 'package:resilience/transport/lora_transport.dart';
import 'package:resilience/transport/transport.dart';

/// A fake Meshtastic link that loops every sent frame back out (optionally
/// shuffled / duplicated) so the LoRa transport can be exercised with no radio.
class FakeMeshLink implements MeshtasticLink {
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();
  final List<Uint8List> sent = <Uint8List>[];

  @override
  bool isUp = true;

  @override
  Stream<Uint8List> get frames => _controller.stream;

  @override
  Future<void> sendFrame(Uint8List frame) async {
    sent.add(Uint8List.fromList(frame));
  }

  /// Manually deliver a frame to listeners (simulates the radio receiving).
  void deliver(Uint8List frame) => _controller.add(Uint8List.fromList(frame));

  @override
  Future<void> close() async {
    await _controller.close();
  }
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

  Future<SignedEvent> sos() => factory.buildFromMessage(
        keyPair: alice,
        clock: LamportClock(),
        type: EventType.EVENT_TYPE_HELP_REQUESTED,
        body: HelpRequestBody(freeform: 'trapped, need water'),
      );

  group('LoraCodec fragment/reassemble', () {
    test('single-fragment event round-trips', () {
      final payload = Uint8List.fromList(List<int>.generate(50, (i) => i));
      final frames = LoraCodec.fragmentBytes(payload, msgId: 7);
      expect(frames.length, 1);
      final re = LoraReassembler();
      final out = re.addFragment(frames.single);
      expect(out, equals(payload));
    });

    test('multi-fragment payload round-trips in order', () {
      final payload =
          Uint8List.fromList(List<int>.generate(1000, (i) => (i * 13) % 256));
      final frames = LoraCodec.fragmentBytes(payload, msgId: 9);
      expect(frames.length, greaterThan(1));
      for (final f in frames) {
        expect(f.length, lessThanOrEqualTo(LoraCodec.maxFragmentBytes));
      }
      final re = LoraReassembler();
      Uint8List? out;
      for (final f in frames) {
        out = re.addFragment(f) ?? out;
      }
      expect(out, equals(payload));
    });

    test('out-of-order + duplicate fragments still reassemble once', () {
      final payload =
          Uint8List.fromList(List<int>.generate(800, (i) => (i * 7) % 256));
      final frames = LoraCodec.fragmentBytes(payload, msgId: 3);
      final re = LoraReassembler();
      // Shuffle-ish: reverse, and feed each twice.
      final order = frames.reversed.toList();
      var completions = 0;
      for (final f in order) {
        if (re.addFragment(f) != null) completions++;
        if (re.addFragment(f) != null) completions++; // duplicate
      }
      expect(completions, 1, reason: 'exactly one completion despite dupes');
    });

    test('rebroadcast of a completed message is deduped', () {
      final payload = Uint8List.fromList(List<int>.generate(60, (i) => i));
      final re = LoraReassembler();
      // First delivery under msgId 1.
      final a = LoraCodec.fragmentBytes(payload, msgId: 1);
      expect(re.addFragment(a.single), isNotNull);
      // Same payload rebroadcast under a different msgId 2 => deduped.
      final b = LoraCodec.fragmentBytes(payload, msgId: 2);
      expect(re.addFragment(b.single), isNull);
    });

    test('malformed frame is ignored', () {
      final re = LoraReassembler();
      expect(re.addFragment(Uint8List.fromList([0, 1, 2])), isNull);
      expect(re.addFragment(Uint8List.fromList([0x4c, 9, 0, 0, 0, 1, 5])),
          isNull); // bad version + bodyLen mismatch
    });

    test('too-large payload is rejected', () {
      final big = Uint8List(LoraCodec.maxPayloadBytes + 1);
      expect(() => LoraCodec.fragmentBytes(big, msgId: 1),
          throwsA(isA<LoraTooLargeException>()));
    });
  });

  group('LoraCodec eligibility', () {
    test('compact kinds are eligible, media/large kinds are not', () {
      expect(LoraCodec.isLoraEligible(EventType.EVENT_TYPE_HELP_REQUESTED),
          isTrue);
      expect(LoraCodec.isLoraEligible(EventType.EVENT_TYPE_EMERGENCY_ALERT),
          isTrue);
      expect(LoraCodec.isLoraEligible(EventType.EVENT_TYPE_LOCATION_SHARE),
          isTrue);
      // Messaging (may carry ciphertext/attachments) is NOT eligible.
      expect(
          LoraCodec.isLoraEligible(EventType.EVENT_TYPE_MESSAGE_SENT), isFalse);
      expect(LoraCodec.isLoraEligible(EventType.EVENT_TYPE_CHANNEL_CREATED),
          isFalse);
    });

    test('fragmenting an ineligible event throws', () async {
      final msg = await factory.buildFromMessage(
        keyPair: alice,
        clock: LamportClock(),
        type: EventType.EVENT_TYPE_MESSAGE_SENT,
        body: MessageBody(ciphertext: Uint8List.fromList([1, 2, 3])),
      );
      expect(() => LoraCodec.fragmentEvent(msg, msgId: 1),
          throwsA(isA<LoraIneligibleException>()));
    });
  });

  group('LoraCodec signed-event round-trip', () {
    test('a signed SOS survives fragment -> reassemble -> verify', () async {
      final event = await sos();
      final frames = LoraCodec.fragmentEvent(event, msgId: 42);
      final re = LoraReassembler();
      Uint8List? out;
      for (final f in frames) {
        out = re.addFragment(f) ?? out;
      }
      expect(out, isNotNull);
      final decoded = SignedEvent.fromBuffer(out!);
      expect(await factory.verifyEvent(decoded), isTrue);
      expect(decoded.header.type, EventType.EVENT_TYPE_HELP_REQUESTED);
    });
  });

  group('LoraTransport over a fake link', () {
    test('sends eligible events as fragments; refuses ineligible', () async {
      final link = FakeMeshLink();
      final transport = LoraTransport(link: link);
      await transport.start();
      final session = await transport
          .connect(const DiscoveredPeer(id: 'mesh', displayName: 'm', via: TransportKind.meshtastic));

      final event = await sos();
      await session.send(event.writeToBuffer());
      expect(link.sent, isNotEmpty);

      final msg = await factory.buildFromMessage(
        keyPair: alice,
        clock: LamportClock(),
        type: EventType.EVENT_TYPE_MESSAGE_SENT,
        body: MessageBody(ciphertext: Uint8List.fromList([9, 9, 9])),
      );
      link.sent.clear();
      await session.send(msg.writeToBuffer());
      expect(link.sent, isEmpty, reason: 'ineligible event is not sent');
      await session.close();
    });

    test('incoming fragments surface a reassembled payload once', () async {
      final link = FakeMeshLink();
      final transport = LoraTransport(link: link);
      await transport.start();
      final session = await transport
          .connect(const DiscoveredPeer(id: 'mesh', displayName: 'm', via: TransportKind.meshtastic));

      final event = await sos();
      final frames = LoraCodec.fragmentEvent(event, msgId: 5);

      final got = <Uint8List>[];
      final done = Completer<void>();
      final sub = session.incoming.listen((p) {
        got.add(p);
        if (!done.isCompleted) done.complete();
      });

      for (final f in frames) {
        link.deliver(f);
      }
      // Rebroadcast everything again — must not surface a second time.
      for (final f in frames) {
        link.deliver(f);
      }
      await done.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(got.length, 1);
      final decoded = SignedEvent.fromBuffer(got.single);
      expect(await factory.verifyEvent(decoded), isTrue);
      await sub.cancel();
      await session.close();
    });
  });
}
