import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/db/database.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/messaging/attachment_cipher.dart';
import 'package:resilience/messaging/blob_transport.dart';
import 'package:resilience/messaging/message_flow.dart';
import 'package:resilience/messaging/message_payload.dart';
import 'package:resilience/messaging/secure_session.dart';
import 'package:resilience/messaging/signal_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A -> B secure messaging end to end', () {
    late Signer signer;
    late KeyPairData aliceKp;
    late KeyPairData bobKp;

    setUp(() async {
      signer = Signer();
      aliceKp = await signer.generateKeyPair();
      bobKp = await signer.generateKeyPair();
    });

    Future<(MessageFlow, MessageFlow)> establish() async {
      final dbBob = AppDatabase.memory();
      addTearDown(dbBob.close);
      final bobStore = await SignalKeys.loadDurableStore(dbBob.signalDao);

      // Bob's prekey bundle from his durable store.
      final bobId = await bobStore.getIdentityKeyPair();
      final bobReg = await bobStore.getLocalRegistrationId();
      final bobSigned = await bobStore.loadSignedPreKey(0);
      final bobPre = await bobStore.loadPreKey(1);
      final bobBundle = PreKeyBundle(
        bobReg,
        1,
        1,
        bobPre.getKeyPair().publicKey,
        0,
        bobSigned.getKeyPair().publicKey,
        bobSigned.signature,
        bobId.getPublicKey(),
      );

      final aliceKeys = await SignalKeys.generate();
      final aliceStore = await aliceKeys.buildStore();

      final aliceToBob = await SecureSession.initiate(
        localStore: aliceStore,
        remoteAddress: const SignalProtocolAddress('bob', 1),
        remoteBundle: bobBundle,
      );
      final bobFromAlice = SecureSession.forRemote(
        localStore: bobStore,
        remoteAddress: const SignalProtocolAddress('alice', 1),
      );

      final aliceFlow = MessageFlow(
        selfKeyPair: aliceKp,
        clock: LamportClock(),
        session: aliceToBob,
        factory: EventFactory(signer: signer),
      );
      final bobFlow = MessageFlow(
        selfKeyPair: bobKp,
        clock: LamportClock(),
        session: bobFromAlice,
        factory: EventFactory(signer: signer),
      );
      return (aliceFlow, bobFlow);
    }

    test('text + photo + audio round trip through store + sync seam', () async {
      final (aliceFlow, bobFlow) = await establish();
      final blob = InMemoryBlobTransport();

      // Fake "photo" and "audio" bytes (the re-encode/EXIF steps are UI-side).
      final photo = Uint8List.fromList(List<int>.generate(2000, (i) => i % 256));
      final audio = Uint8List.fromList(List<int>.generate(1500, (i) => (i * 7) % 256));

      final photoAtt = await MessageFlow.attachBytes(
        blob: blob,
        plaintext: photo,
        mime: 'image/jpeg',
        thumbnail: Uint8List.fromList([1, 2, 3, 4]),
        width: 1600,
        height: 1200,
      );
      final audioAtt = await MessageFlow.attachBytes(
        blob: blob,
        plaintext: audio,
        mime: 'audio/aac',
        durationMs: 4200,
      );

      // CRITICAL privacy check: what the blob "server" holds is ONLY ciphertext
      // — never the plaintext bytes.
      for (final stored in blob.stored.values) {
        expect(_contains(stored, photo), isFalse,
            reason: 'blob store must hold only ciphertext (photo leaked)');
        expect(_contains(stored, audio), isFalse,
            reason: 'blob store must hold only ciphertext (audio leaked)');
      }

      final sentText = await aliceFlow.sendPayload(
        recipientPubkey: bobKp.publicKey,
        payload: MessagePayload(kind: 'text', text: 'meet at the shelter'),
      );
      final sentPhoto = await aliceFlow.sendPayload(
        recipientPubkey: bobKp.publicKey,
        payload: MessagePayload(kind: 'photo', attachments: [photoAtt]),
      );
      final sentAudio = await aliceFlow.sendPayload(
        recipientPubkey: bobKp.publicKey,
        payload: MessagePayload(kind: 'audio', attachments: [audioAtt]),
      );

      // Bob receives (the sync seam just carries the signed events).
      final p1 = await bobFlow.receivePayload(sentText.event);
      final p2 = await bobFlow.receivePayload(sentPhoto.event);
      final p3 = await bobFlow.receivePayload(sentAudio.event);

      expect(p1!.text, 'meet at the shelter');

      final gotPhoto = await MessageFlow.fetchAttachment(
          blob: blob, attachment: p2!.attachments.single);
      expect(gotPhoto, equals(photo));
      expect(p2.attachments.single.width, 1600);

      final gotAudio = await MessageFlow.fetchAttachment(
          blob: blob, attachment: p3!.attachments.single);
      expect(gotAudio, equals(audio));
      expect(p3.attachments.single.durationMs, 4200);
    });

    test('delivery state progresses queued -> delivered -> read', () async {
      final (aliceFlow, bobFlow) = await establish();
      final sent = await aliceFlow.sendPayload(
        recipientPubkey: bobKp.publicKey,
        payload: MessagePayload(text: 'hi'),
      );
      final events = <SignedEvent>[sent.event];

      // No route yet.
      expect(
        MessageFlow.deliveryState(sent.messageId, events, hasRoute: false),
        DeliveryState.queued,
      );
      // In flight.
      expect(
        MessageFlow.deliveryState(sent.messageId, events, hasRoute: true),
        DeliveryState.propagating,
      );
      // Bob delivers + reads.
      events.add(await bobFlow.markDelivered(sent.messageId));
      expect(MessageFlow.deliveryState(sent.messageId, events),
          DeliveryState.delivered);
      events.add(await bobFlow.markRead(sent.messageId));
      expect(
          MessageFlow.deliveryState(sent.messageId, events), DeliveryState.read);
    });

    test('tampered attachment ciphertext fails hash/auth and is not shown',
        () async {
      final (aliceFlow, bobFlow) = await establish();
      final blob = InMemoryBlobTransport();
      final photo = Uint8List.fromList(List<int>.generate(500, (i) => i % 256));

      final att = await MessageFlow.attachBytes(
        blob: blob,
        plaintext: photo,
        mime: 'image/jpeg',
      );
      final sent = await aliceFlow.sendPayload(
        recipientPubkey: bobKp.publicKey,
        payload: MessagePayload(kind: 'photo', attachments: [att]),
      );
      final payload = await bobFlow.receivePayload(sent.event);

      // Attacker flips bytes of the stored blob WITHOUT changing the address.
      final stored = blob.stored[att.sha256]!;
      stored[stored.length - 1] ^= 0xFF;

      // Download+verify must reject (sha256 no longer matches) — never shown.
      await expectLater(
        MessageFlow.fetchAttachment(
            blob: blob, attachment: payload!.attachments.single),
        throwsA(isA<AttachmentException>()),
      );
    });

    test('tampered message ciphertext is rejected and not shown', () async {
      final (aliceFlow, bobFlow) = await establish();
      final sent = await aliceFlow.sendPayload(
        recipientPubkey: bobKp.publicKey,
        payload: MessagePayload(text: 'secret'),
      );
      // Corrupt the Signal ciphertext in the event body. The event_id no
      // longer matches the body, so EventFactory.verifyEvent rejects it and
      // receivePayload returns null — the forged message is never shown.
      final body = MessageBody.fromBuffer(sent.event.body);
      final ct = Uint8List.fromList(body.ciphertext);
      ct[ct.length - 1] ^= 0xFF;
      body.ciphertext = ct;
      final tampered = sent.event.deepCopy()..body = body.writeToBuffer();

      final payload = await bobFlow.receivePayload(tampered);
      expect(payload, isNull, reason: 'tampered event must not be shown');
    });
  });
}

bool _contains(List<int> haystack, List<int> needle) {
  if (needle.isEmpty || needle.length > haystack.length) return false;
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}
