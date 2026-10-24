import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:resilience/db/database.dart';
import 'package:resilience/messaging/secure_session.dart';
import 'package:resilience/messaging/signal_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Durable Drift-backed Signal store', () {
    test('generates identity on first run and re-hydrates it', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final store = await SignalKeys.loadDurableStore(db.signalDao);
      final idA = (await store.getIdentityKeyPair()).getPublicKey().serialize();
      final regA = await store.getLocalRegistrationId();

      // "Restart": a new store over the same DB must load the SAME identity.
      final store2 = await SignalKeys.loadDurableStore(db.signalDao);
      final idB = (await store2.getIdentityKeyPair()).getPublicKey().serialize();
      final regB = await store2.getLocalRegistrationId();

      expect(idB, equals(idA));
      expect(regB, equals(regA));
      // Prekeys were persisted on first run.
      expect(await store2.containsSignedPreKey(0), isTrue);
      expect(await store2.containsPreKey(1), isTrue);
    });

    test('a session established before restart survives and keeps decrypting',
        () async {
      // Bob uses a durable store; Alice uses an in-memory store.
      final dbBob = AppDatabase.memory();
      addTearDown(dbBob.close);

      final bobStore = await SignalKeys.loadDurableStore(dbBob.signalDao);

      // Build Bob's publishable prekey bundle from his durable store.
      final bobIdentity = await bobStore.getIdentityKeyPair();
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
        bobIdentity.getPublicKey(),
      );

      final aliceKeys = await SignalKeys.generate();
      final aliceStore = await aliceKeys.buildStore();

      final aliceToBob = await SecureSession.initiate(
        localStore: aliceStore,
        remoteAddress: const SignalProtocolAddress('bob', 1),
        remoteBundle: bobBundle,
      );

      // First (prekey) message completes X3DH on Bob's side via his durable store.
      final c1 = await aliceToBob.encryptText('hello-before-restart');
      final bobFromAlice = SecureSession.forRemote(
        localStore: bobStore,
        remoteAddress: const SignalProtocolAddress('alice', 1),
      );
      expect(await bobFromAlice.decryptText(c1), 'hello-before-restart');

      // "Restart" Bob: reload a fresh durable store from the same DB.
      final bobStore2 = await SignalKeys.loadDurableStore(dbBob.signalDao);
      final bobFromAlice2 = SecureSession.forRemote(
        localStore: bobStore2,
        remoteAddress: const SignalProtocolAddress('alice', 1),
      );
      // A follow-up message decrypts using the PERSISTED ratchet session.
      final c2 = await aliceToBob.encryptText('hello-after-restart');
      expect(await bobFromAlice2.decryptText(c2), 'hello-after-restart');
    });
  });
}
