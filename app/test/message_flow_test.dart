import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/messaging/message_flow.dart';
import 'package:resilience/messaging/secure_session.dart';
import 'package:resilience/messaging/signal_keys.dart';

void main() {
  late Signer signer;
  late EventFactory factory;

  setUp(() {
    signer = Signer();
    factory = EventFactory(signer: signer);
  });

  test(
      'sendDirect -> MESSAGE_SENT; receive decrypts + MESSAGE_DELIVERED; '
      'state queued -> delivered; relay cannot decrypt but carries it',
      () async {
    // --- Signing identities (event authors) ---
    final aliceId = await signer.generateKeyPair();
    final bobId = await signer.generateKeyPair();

    // --- Signal E2E key material + sessions ---
    final aliceKeys = await SignalKeys.generate();
    final bobKeys = await SignalKeys.generate();
    final aliceStore = await aliceKeys.buildStore();
    final bobStore = await bobKeys.buildStore();

    final bobBundle = SignalKeys.preKeyBundleFromBody(
      bobKeys.toPrekeyBundleBody(),
    );
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
      selfKeyPair: aliceId,
      clock: LamportClock(),
      session: aliceToBob,
      factory: factory,
    );
    final bobFlow = MessageFlow(
      selfKeyPair: bobId,
      clock: LamportClock(),
      session: bobFromAlice,
      factory: factory,
    );

    // Alice sends a direct message to Bob.
    final sent = await aliceFlow.sendDirect(
      recipientPubkey: bobId.publicKey,
      plaintext: 'meet at the shelter',
    );
    expect(sent.event.header.type, EventType.EVENT_TYPE_MESSAGE_SENT);

    // The log so far: just the MESSAGE_SENT. State is propagating (route
    // exists) / queued (no route).
    final log = <SignedEvent>[sent.event];
    expect(
      MessageFlow.deliveryState(sent.messageId, log, hasRoute: false),
      DeliveryState.queued,
    );
    expect(
      MessageFlow.deliveryState(sent.messageId, log, hasRoute: true),
      DeliveryState.propagating,
    );

    // --- Store-carry-forward: a relay applies the event but cannot read it ---
    final relayId = await signer.generateKeyPair();
    final relayKeys = await SignalKeys.generate();
    final relayStore = await relayKeys.buildStore();
    // The relay has a session facade toward Alice but no handshake/keys to
    // decrypt a message that was sealed for Bob.
    final relaySession = SecureSession.forRemote(
      localStore: relayStore,
      remoteAddress: const SignalProtocolAddress('alice', 1),
    );
    final relayFlow = MessageFlow(
      selfKeyPair: relayId,
      clock: LamportClock(),
      session: relaySession,
      factory: factory,
    );

    // The event verifies (so the relay WILL carry it), but receive() returns
    // null because the recipient hint is not the relay's.
    expect(await factory.verifyEvent(sent.event), isTrue);
    final relayPlain = await relayFlow.receive(sent.event);
    expect(relayPlain, isNull, reason: 'relay is not the addressee');

    // Even if the relay tried to force-decrypt the ciphertext it cannot.
    final body = MessageBody.fromBuffer(sent.event.body);
    await expectLater(
      relaySession.decrypt(Uint8List.fromList(body.ciphertext)),
      throwsA(isA<Object>()),
    );

    // --- Bob receives: decrypts + emits MESSAGE_DELIVERED ---
    SignedEvent? deliveredReceipt;
    final plaintext = await bobFlow.receive(
      sent.event,
      onReceipt: (r) async => deliveredReceipt = r,
    );
    expect(plaintext, 'meet at the shelter');
    expect(deliveredReceipt, isNotNull);
    expect(
      deliveredReceipt!.header.type,
      EventType.EVENT_TYPE_MESSAGE_DELIVERED,
    );

    // With the delivered receipt in the log, state advances to delivered.
    log.add(deliveredReceipt!);
    expect(
      MessageFlow.deliveryState(sent.messageId, log),
      DeliveryState.delivered,
    );

    // Read receipt advances to read.
    final readReceipt = await bobFlow.markRead(sent.messageId);
    log.add(readReceipt);
    expect(
      MessageFlow.deliveryState(sent.messageId, log),
      DeliveryState.read,
    );
  });

  test('group message after removing a member: removed member cannot decrypt',
      () async {
    const baseGroupId = 'mission-2193-ops';
    final aliceId = await signer.generateKeyPair();

    // Epoch 0: alice + mallory.
    final aliceGroup0 =
        GroupSecureSession.create(groupId: baseGroupId, selfName: 'alice');
    final malloryGroup =
        GroupSecureSession.create(groupId: baseGroupId, selfName: 'mallory');

    final aliceFlow = GroupMessageFlow(
      selfKeyPair: aliceId,
      clock: LamportClock(),
      channelId: baseGroupId,
      group: aliceGroup0,
      epoch: 0,
      factory: factory,
    );

    // Alice distributes her epoch-0 sender key to Mallory.
    final dist0 = await aliceGroup0.createDistribution();
    await malloryGroup.processDistribution(
      senderName: 'alice',
      distribution: SenderKeyDistributionMessageWrapper.fromSerialized(
        dist0.serialize(),
      ),
    );

    final sent0 = await aliceFlow.sendGroup(plaintext: 'epoch0 hello');
    final body0 = MessageBody.fromBuffer(sent0.event.body);
    expect(body0.groupEpoch, 0);
    // Mallory (a member in epoch 0) can read it.
    expect(
      await malloryGroup.decryptText(
        senderName: 'alice',
        ciphertext: Uint8List.fromList(body0.ciphertext),
      ),
      'epoch0 hello',
    );

    // Mallory is removed -> rotate to epoch 1. CHANNEL_MEMBERSHIP records it.
    final membership = await aliceFlow.membershipChange(
      removed: [
        // In a real system this would be Mallory's pubkey; any bytes suffice
        // for the epoch-rotation semantics under test.
        [1, 2, 3, 4],
      ],
      epoch: 1,
    );
    expect(
      membership.header.type,
      EventType.EVENT_TYPE_CHANNEL_MEMBERSHIP,
    );
    aliceFlow.rotateEpoch(baseGroupId, 1);
    expect(aliceFlow.epoch, 1);

    // Remaining member Bob joins at epoch 1; Alice re-distributes.
    final bobGroup = GroupSecureSession.create(
      groupId: baseGroupId,
      selfName: 'bob',
      epoch: 1,
    );
    final dist1 = await aliceGroup0.createDistribution();
    await bobGroup.processDistribution(
      senderName: 'alice',
      distribution: SenderKeyDistributionMessageWrapper.fromSerialized(
        dist1.serialize(),
      ),
    );

    final sent1 = await aliceFlow.sendGroup(plaintext: 'epoch1 secret');
    final body1 = MessageBody.fromBuffer(sent1.event.body);
    expect(body1.groupEpoch, 1);

    // Bob (current member) can read the epoch-1 message.
    expect(
      await bobGroup.decryptText(
        senderName: 'alice',
        ciphertext: Uint8List.fromList(body1.ciphertext),
      ),
      'epoch1 secret',
    );

    // Mallory, stuck at epoch 0 with no epoch-1 sender key, cannot decrypt.
    await expectLater(
      malloryGroup.decrypt(
        senderName: 'alice',
        ciphertext: Uint8List.fromList(body1.ciphertext),
      ),
      throwsA(isA<Object>()),
    );
  });
}
