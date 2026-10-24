import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/logistics/capabilities.dart';

void main() {
  late Signer signer;
  late EventFactory factory;
  late CapabilityVerifier verifier;
  late KeyPairData missionCreator; // root authority for mission:2193
  late KeyPairData chris; // the driver
  late KeyPairData stranger; // a non-authorized issuer

  const String mission2193 = '2193';
  const String mission2194 = '2194';

  setUp(() async {
    signer = Signer();
    factory = EventFactory(signer: signer);
    verifier = CapabilityVerifier(factory: factory);
    missionCreator = await signer.generateKeyPair();
    chris = await signer.generateKeyPair();
    stranger = await signer.generateKeyPair();
  });

  Map<String, Set<AuthorityKey>> roots() => <String, Set<AuthorityKey>>{
        missionScope(mission2193): <AuthorityKey>{
          AuthorityKey(missionCreator.publicKey),
        },
        missionScope(mission2194): <AuthorityKey>{
          AuthorityKey(missionCreator.publicKey),
        },
      };

  test('MISSION_2193_DRIVER grants only mission 2193, not 2194', () async {
    final clock = LamportClock();
    final grant = await verifier.grant(
      issuerKeyPair: missionCreator,
      clock: clock,
      capabilityId: 'cap-chris-2193',
      subjectPubkey: chris.publicKey,
      scope: missionScope(mission2193),
      actions: kMissionDriverActions,
    );

    final caps = await verifier.foldForSubject(
      subjectPubkey: chris.publicKey,
      events: [grant],
      rootAuthoritiesByScope: roots(),
    );

    expect(
      caps.can('see_exact_pickup', scope: missionScope(mission2193)),
      isTrue,
    );
    expect(
      caps.can('confirm_delivery', scope: missionScope(mission2193)),
      isTrue,
    );
    // Different mission scope => denied.
    expect(
      caps.can('see_exact_pickup', scope: missionScope(mission2194)),
      isFalse,
    );
  });

  test('a capability signed by a non-authorized issuer is rejected', () async {
    final clock = LamportClock();
    // Stranger (not the mission creator, no grant capability) tries to grant.
    final forged = await verifier.grant(
      issuerKeyPair: stranger,
      clock: clock,
      capabilityId: 'cap-forged',
      subjectPubkey: chris.publicKey,
      scope: missionScope(mission2193),
      actions: kMissionDriverActions,
    );

    final caps = await verifier.foldForSubject(
      subjectPubkey: chris.publicKey,
      events: [forged],
      rootAuthoritiesByScope: roots(),
    );

    expect(caps.isEmpty, isTrue);
    expect(
      caps.can('see_exact_pickup', scope: missionScope(mission2193)),
      isFalse,
    );
  });

  test('CAPABILITY_REVOKED removes a previously granted capability', () async {
    final clock = LamportClock();
    final grant = await verifier.grant(
      issuerKeyPair: missionCreator,
      clock: clock,
      capabilityId: 'cap-chris-2193',
      subjectPubkey: chris.publicKey,
      scope: missionScope(mission2193),
      actions: kMissionDriverActions,
    );
    final revoke = await verifier.revoke(
      issuerKeyPair: missionCreator,
      clock: clock,
      capabilityId: 'cap-chris-2193',
      subjectPubkey: chris.publicKey,
      scope: missionScope(mission2193),
    );

    final caps = await verifier.foldForSubject(
      subjectPubkey: chris.publicKey,
      events: [grant, revoke],
      rootAuthoritiesByScope: roots(),
    );

    expect(
      caps.can('see_exact_pickup', scope: missionScope(mission2193)),
      isFalse,
    );
  });

  test('expiry is respected', () async {
    final clock = LamportClock();
    const int expiresMs = 1_000_000;
    final grant = await verifier.grant(
      issuerKeyPair: missionCreator,
      clock: clock,
      capabilityId: 'cap-chris-2193',
      subjectPubkey: chris.publicKey,
      scope: missionScope(mission2193),
      actions: kMissionDriverActions,
      validUntilMs: expiresMs,
    );

    // Before expiry.
    final live = await verifier.foldForSubject(
      subjectPubkey: chris.publicKey,
      events: [grant],
      rootAuthoritiesByScope: roots(),
      nowMs: expiresMs - 1,
    );
    expect(
      live.can('see_exact_pickup',
          scope: missionScope(mission2193), nowMs: expiresMs - 1),
      isTrue,
    );

    // After expiry: never honored.
    final expired = await verifier.foldForSubject(
      subjectPubkey: chris.publicKey,
      events: [grant],
      rootAuthoritiesByScope: roots(),
      nowMs: expiresMs + 1,
    );
    expect(
      expired.can('see_exact_pickup',
          scope: missionScope(mission2193), nowMs: expiresMs + 1),
      isFalse,
    );
  });

  test('delegated authority: a grant-holder can issue for the scope', () async {
    final clock = LamportClock();
    final authority = await signer.generateKeyPair();

    // Mission creator grants `authority` a grant capability for mission:2193.
    final delegate = await verifier.grant(
      issuerKeyPair: missionCreator,
      clock: clock,
      capabilityId: 'cap-authority-grant',
      subjectPubkey: authority.publicKey,
      scope: missionScope(mission2193),
      actions: const [kGrantAction],
    );

    // `authority` (lamport after the delegate) grants Chris driver rights.
    final grantChris = await verifier.grant(
      issuerKeyPair: authority,
      clock: clock..observe(Int64(10)),
      capabilityId: 'cap-chris-2193',
      subjectPubkey: chris.publicKey,
      scope: missionScope(mission2193),
      actions: kMissionDriverActions,
    );

    final caps = await verifier.foldForSubject(
      subjectPubkey: chris.publicKey,
      events: [delegate, grantChris],
      rootAuthoritiesByScope: roots(),
    );

    expect(
      caps.can('confirm_pickup', scope: missionScope(mission2193)),
      isTrue,
    );
  });
}
