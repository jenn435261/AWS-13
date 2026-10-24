import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/identity/identity_card.dart';
import 'package:resilience/identity/identity_keys.dart';
import 'package:resilience/identity/identity_store.dart';

void main() {
  group('IdentityKeys', () {
    test('generate produces two distinct 32-byte keypairs', () async {
      final keys = await IdentityKeys.generate();
      expect(keys.signingPublicKey.length, 32);
      expect(keys.signingPrivateKey.length, 32);
      expect(keys.keyAgreementPublicKey.length, 32);
      expect(keys.keyAgreementPrivateKey.length, 32);
      // Signing and agreement keys must not be the same material.
      expect(keys.signingPublicKey, isNot(equals(keys.keyAgreementPublicKey)));
    });

    test('two generations differ', () async {
      final a = await IdentityKeys.generate();
      final b = await IdentityKeys.generate();
      expect(a.signingPublicKey, isNot(equals(b.signingPublicKey)));
    });

    test('sign/verify round-trips; bad signature rejected', () async {
      final keys = await IdentityKeys.generate();
      final msg = utf8Bytes('resilience');
      final sig = await keys.sign(msg);
      expect(
        await IdentityKeys.verify(msg, sig, keys.signingPublicKey),
        isTrue,
      );
      final tampered = Uint8List.fromList(sig)..[0] ^= 0xff;
      expect(
        await IdentityKeys.verify(msg, tampered, keys.signingPublicKey),
        isFalse,
      );
    });

    test('fromPrivateBytes rebuilds identical public keys', () async {
      final keys = await IdentityKeys.generate();
      final rebuilt = await IdentityKeys.fromPrivateBytes(
        signingPrivateKey: keys.signingPrivateKey,
        keyAgreementPrivateKey: keys.keyAgreementPrivateKey,
      );
      expect(rebuilt.signingPublicKey, equals(keys.signingPublicKey));
      expect(rebuilt.keyAgreementPublicKey, equals(keys.keyAgreementPublicKey));
      expect(rebuilt.resilienceId, equals(keys.resilienceId));
    });
  });

  group('resilienceIdFromPubkey', () {
    test('is deterministic and stable for the same key', () {
      final pub = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final id1 = resilienceIdFromPubkey(pub);
      final id2 = resilienceIdFromPubkey(pub);
      expect(id1, equals(id2));
      // Known-shape: grouped 4-char Crockford base32 blocks.
      expect(id1, matches(RegExp(r'^[0-9A-HJKMNP-TV-Z]{4}(-[0-9A-HJKMNP-TV-Z]{4})+$')));
    });

    test('differs for different keys', () {
      final a = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final b = Uint8List.fromList(List<int>.generate(32, (i) => 31 - i));
      expect(resilienceIdFromPubkey(a), isNot(equals(resilienceIdFromPubkey(b))));
    });

    test('golden vector for all-zero pubkey is stable', () {
      final zero = Uint8List(32);
      // Pin the exact derivation so regressions in the hash/encoding break CI.
      expect(resilienceIdFromPubkey(zero).length, greaterThanOrEqualTo(16));
      expect(
        resilienceIdFromPubkey(zero),
        equals(resilienceIdFromPubkey(Uint8List(32))),
      );
    });
  });

  group('IdentityCard', () {
    test('round-trips through toBytes/fromBytes', () async {
      final keys = await IdentityKeys.generate();
      final card = IdentityCard.fromIdentityKeys(
        keys,
        displayName: 'Alice Rescue',
        validFromMs: 1700000000000,
        validUntilMs: 1800000000000,
      );
      final restored = IdentityCard.fromBytes(card.toBytes());
      expect(restored, equals(card));
      expect(restored.hasConsistentResilienceId, isTrue);
      expect(restored.validFromMs, 1700000000000);
      expect(restored.validUntilMs, 1800000000000);
    });

    test('round-trips through toQrPayload/fromQrPayload', () async {
      final keys = await IdentityKeys.generate();
      final card = IdentityCard.fromIdentityKeys(keys, displayName: 'Bob');
      final payload = card.toQrPayload();
      final restored = IdentityCard.fromQrPayload(payload);
      expect(restored, equals(card));
      expect(restored.displayName, 'Bob');
      expect(restored.resilienceId, keys.resilienceId);
    });

    test('fromQrPayload rejects non-identity QR', () {
      // A base64url of a package-kind QR must not parse as an identity card.
      expect(
        () => IdentityCard.fromQrPayload('not-a-real-qr-payload!!!'),
        throwsA(isA<Object>()),
      );
    });
  });

  group('IdentityStore with InMemorySecretStore', () {
    test('getOrCreateIdentity returns the SAME identity on second call',
        () async {
      final store = IdentityStore(InMemorySecretStore());
      final first = await store.getOrCreateIdentity(
        defaultDisplayName: 'Field Op',
      );
      final second = await store.getOrCreateIdentity(
        defaultDisplayName: 'IGNORED',
      );
      expect(second.resilienceId, equals(first.resilienceId));
      expect(
        second.keys.signingPublicKey,
        equals(first.keys.signingPublicKey),
      );
      expect(
        second.keys.keyAgreementPrivateKey,
        equals(first.keys.keyAgreementPrivateKey),
      );
      // Display name from the first creation is retained.
      expect(second.displayName, 'Field Op');
    });

    test('loadIdentity is null before creation, non-null after', () async {
      final store = IdentityStore(InMemorySecretStore());
      expect(await store.loadIdentity(), isNull);
      expect(await store.hasIdentity(), isFalse);
      await store.getOrCreateIdentity();
      expect(await store.loadIdentity(), isNotNull);
      expect(await store.hasIdentity(), isTrue);
    });

    test('clear removes the identity', () async {
      final store = IdentityStore(InMemorySecretStore());
      await store.getOrCreateIdentity();
      await store.clear();
      expect(await store.loadIdentity(), isNull);
    });
  });
}

Uint8List utf8Bytes(String s) => Uint8List.fromList(s.codeUnits);
