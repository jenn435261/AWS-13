import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:resilience/messaging/secure_session.dart';
import 'package:resilience/messaging/signal_keys.dart';

void main() {
  group('Signal 1:1 (X3DH + Double Ratchet)', () {
    test('Alice -> Bob: Hello end to end', () async {
      // Each party installs: generate identity + registration + prekeys.
      final aliceKeys = await SignalKeys.generate();
      final bobKeys = await SignalKeys.generate();

      final aliceStore = await aliceKeys.buildStore();
      final bobStore = await bobKeys.buildStore();

      // Bob publishes a prekey bundle (as a protobuf body).
      final bobBundleBody = bobKeys.toPrekeyBundleBody();
      final bobBundle = SignalKeys.preKeyBundleFromBody(bobBundleBody);

      final bobAddress = const SignalProtocolAddress('bob', 1);
      final aliceAddress = const SignalProtocolAddress('alice', 1);

      // Alice builds a session toward Bob and encrypts "Hello".
      final aliceToBob = await SecureSession.initiate(
        localStore: aliceStore,
        remoteAddress: bobAddress,
        remoteBundle: bobBundle,
      );
      final ciphertext = await aliceToBob.encryptText('Hello');

      // Bob decrypts to "Hello".
      final bobFromAlice = SecureSession.forRemote(
        localStore: bobStore,
        remoteAddress: aliceAddress,
      );
      final plaintext = await bobFromAlice.decryptText(ciphertext);
      expect(plaintext, 'Hello');
    });

    test('bidirectional conversation after handshake', () async {
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

      final c1 = await aliceToBob.encryptText('ping');
      expect(await bobFromAlice.decryptText(c1), 'ping');

      // Bob replies; ratchet advances in the reverse direction.
      final c2 = await bobFromAlice.encryptText('pong');
      expect(await aliceToBob.decryptText(c2), 'pong');

      final c3 = await aliceToBob.encryptText('ping2');
      expect(await bobFromAlice.decryptText(c3), 'ping2');
    });

    test('prekey bundle body carries the published public material', () async {
      final keys = await SignalKeys.generate();
      final body = keys.toPrekeyBundleBody();
      expect(body.identityPubkey,
          equals(keys.identityKeyPair.getPublicKey().serialize()));
      expect(body.registrationId, keys.registrationId);
      expect(body.signedPrekeyId, keys.signedPreKey.id);
      expect(body.prekeyId, keys.preKeys.first.id);
      expect(body.signedPrekeySig, equals(keys.signedPreKey.signature));
    });
  });

  group('Signal group (Sender-Key)', () {
    test('Alice distributes, Bob processes, group encrypt/decrypt', () async {
      const groupId = 'rescue-ops';
      final alice = GroupSecureSession.create(
        groupId: groupId,
        selfName: 'alice',
      );
      final bob = GroupSecureSession.create(
        groupId: groupId,
        selfName: 'bob',
      );

      // Alice distributes her sender key; Bob processes it.
      final aliceDist = await alice.createDistribution();
      await bob.processDistribution(
        senderName: 'alice',
        distribution: SenderKeyDistributionMessageWrapper.fromSerialized(
          aliceDist.serialize(),
        ),
      );

      // Alice group-encrypts; Bob group-decrypts.
      final ciphertext = await alice.encryptText('group hello');
      final plaintext = await bob.decryptText(
        senderName: 'alice',
        ciphertext: ciphertext,
      );
      expect(plaintext, 'group hello');
    });

    test('epoch rotation blocks a removed member from future messages',
        () async {
      const groupId = 'rescue-ops';
      // Epoch 0 members: alice, bob, mallory.
      final alice = GroupSecureSession.create(groupId: groupId, selfName: 'alice');
      final mallory =
          GroupSecureSession.create(groupId: groupId, selfName: 'mallory');

      final aliceDist0 = await alice.createDistribution();
      await mallory.processDistribution(
        senderName: 'alice',
        distribution: SenderKeyDistributionMessageWrapper.fromSerialized(
          aliceDist0.serialize(),
        ),
      );
      // Mallory can read epoch-0 traffic.
      final c0 = await alice.encryptText('epoch0');
      expect(
        await mallory.decryptText(senderName: 'alice', ciphertext: c0),
        'epoch0',
      );

      // Mallory is removed -> group rotates to epoch 1. Remaining members
      // re-distribute. Mallory does NOT receive the new distribution.
      alice.rotateEpoch(groupId, 1);
      final bob = GroupSecureSession.create(
        groupId: groupId,
        selfName: 'bob',
        epoch: 1,
      );
      final aliceDist1 = await alice.createDistribution();
      await bob.processDistribution(
        senderName: 'alice',
        distribution: SenderKeyDistributionMessageWrapper.fromSerialized(
          aliceDist1.serialize(),
        ),
      );

      final c1 = await alice.encryptText('epoch1-secret');
      // Bob (current member) can read.
      expect(
        await bob.decryptText(senderName: 'alice', ciphertext: c1),
        'epoch1-secret',
      );
      // Mallory (stuck at epoch 0, no epoch-1 sender key) cannot decrypt.
      await expectLater(
        mallory.decrypt(senderName: 'alice', ciphertext: c1),
        throwsA(isA<Object>()),
      );
    });
  });
}
