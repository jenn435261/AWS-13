import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/state/derived_state.dart';
import 'package:resilience/trust/trust_engine.dart';
import 'package:resilience/trust/trust_roots.dart';

/// Shared test fixtures: a signer, a factory, and a single global clock so that
/// lamport values are monotonic across all authors in a scenario.
late Signer signer;
late EventFactory factory;
late LamportClock clock;

/// A fixed "now" so freshness is deterministic.
const int kNow = 1000000000000; // some fixed epoch-ms

Future<SignedEvent> _build(
  KeyPairData author,
  EventType type,
  dynamic body, {
  int? createdAtMs,
}) {
  return factory.buildFromMessage(
    keyPair: author,
    clock: clock,
    type: type,
    body: body,
    createdAtMs: createdAtMs == null ? null : Int64(createdAtMs),
  );
}

ResourceBody _resource(String id,
    {ProvenanceKind provenance =
        ProvenanceKind.PROVENANCE_KIND_COMMUNITY}) {
  return ResourceBody(
    resourceId: id,
    category: ResourceCategory.RESOURCE_CATEGORY_WATER,
    title: 'Water at $id',
    amount: AmountBand.AMOUNT_BAND_PLENTY,
    availability: Availability.AVAILABILITY_NOW,
    provenance: provenance,
  );
}

ObservationBody _obs(String id, ObservationBody_Kind kind) =>
    ObservationBody(resourceId: id, kind: kind);

void main() {
  setUp(() {
    signer = Signer();
    factory = EventFactory(signer: signer);
    clock = LamportClock();
  });

  group('freshnessFactor', () {
    test('is 1.0 at age 0 and 0.5 at one half-life, monotonic decreasing', () {
      final TrustEngine engine = TrustEngine.fromEvents(
        const <SignedEvent>[],
        roots: TrustRootStore(),
      );
      expect(engine.freshnessFactor(0), closeTo(1.0, 1e-9));
      expect(
        engine.freshnessFactor(TrustEngine.freshnessHalfLifeMs),
        closeTo(0.5, 1e-9),
      );
      // Monotonic decreasing across a sweep of ages.
      double prev = engine.freshnessFactor(0);
      for (int ageMs = 1;
          ageMs <= 24 * 60 * 60 * 1000;
          ageMs += 15 * 60 * 1000) {
        final double f = engine.freshnessFactor(ageMs);
        expect(f, lessThanOrEqualTo(prev));
        prev = f;
      }
    });
  });

  group('corroboration', () {
    test('community resource with 0 observations => unconfirmed, still present',
        () async {
      final KeyPairData alice = await signer.generateKeyPair();
      final List<SignedEvent> log = <SignedEvent>[
        await _build(alice, EventType.EVENT_TYPE_RESOURCE_CREATED,
            _resource('r-1'),
            createdAtMs: kNow),
      ];

      final TrustEngine engine =
          TrustEngine.fromEvents(log, roots: TrustRootStore());
      final TrustProfile p =
          engine.profileForResource('r-1', log, nowMs: kNow);

      expect(p.corroboration.confirmCount, 0);
      expect(p.corroboration.disputeCount, 0);
      expect(p.source.kind, ProvenanceKind.PROVENANCE_KIND_COMMUNITY);
      expect(p.band,
          anyOf(ConfidenceBand.unconfirmed, ConfidenceBand.low));

      // Still present in the ranked projection.
      final WorldState world = WorldState(clock: () => kNow);
      world.rebuildFromEvents(log);
      expect(world.rankedResources().map((ResourceView r) => r.resourceId),
          contains('r-1'));
    });

    test('10 distinct confirms + 1 dispute => high, counts exact', () async {
      final KeyPairData owner = await signer.generateKeyPair();
      final List<SignedEvent> log = <SignedEvent>[
        await _build(owner, EventType.EVENT_TYPE_RESOURCE_CREATED,
            _resource('r-2'),
            createdAtMs: kNow),
      ];
      for (int i = 0; i < 10; i++) {
        final KeyPairData observer = await signer.generateKeyPair();
        log.add(await _build(
            observer,
            EventType.EVENT_TYPE_RESOURCE_CONFIRMED,
            _obs('r-2', ObservationBody_Kind.KIND_CONFIRMED),
            createdAtMs: kNow));
      }
      final KeyPairData disputer = await signer.generateKeyPair();
      log.add(await _build(disputer, EventType.EVENT_TYPE_RESOURCE_DISPUTED,
          _obs('r-2', ObservationBody_Kind.KIND_DISPUTED),
          createdAtMs: kNow));

      final TrustEngine engine =
          TrustEngine.fromEvents(log, roots: TrustRootStore());
      final TrustProfile p =
          engine.profileForResource('r-2', log, nowMs: kNow);

      expect(p.corroboration.confirmCount, 10);
      expect(p.corroboration.disputeCount, 1);
      expect(p.corroboration.distinctObservers, 11);
      expect(p.band, ConfidenceBand.high);
    });

    test('duplicate confirms from the SAME observer count once', () async {
      final KeyPairData owner = await signer.generateKeyPair();
      final KeyPairData observer = await signer.generateKeyPair();
      final List<SignedEvent> log = <SignedEvent>[
        await _build(owner, EventType.EVENT_TYPE_RESOURCE_CREATED,
            _resource('r-3'),
            createdAtMs: kNow),
        await _build(observer, EventType.EVENT_TYPE_RESOURCE_CONFIRMED,
            _obs('r-3', ObservationBody_Kind.KIND_CONFIRMED),
            createdAtMs: kNow),
        await _build(observer, EventType.EVENT_TYPE_RESOURCE_CONFIRMED,
            _obs('r-3', ObservationBody_Kind.KIND_CONFIRMED),
            createdAtMs: kNow),
        await _build(observer, EventType.EVENT_TYPE_RESOURCE_CONFIRMED,
            _obs('r-3', ObservationBody_Kind.KIND_CONFIRMED),
            createdAtMs: kNow),
      ];

      final TrustEngine engine =
          TrustEngine.fromEvents(log, roots: TrustRootStore());
      final TrustProfile p =
          engine.profileForResource('r-3', log, nowMs: kNow);
      expect(p.corroboration.confirmCount, 1);
      expect(p.corroboration.distinctObservers, 1);
    });

    test('same observer confirms then later disputes => counts as dispute',
        () async {
      final KeyPairData owner = await signer.generateKeyPair();
      final KeyPairData observer = await signer.generateKeyPair();
      final List<SignedEvent> log = <SignedEvent>[
        await _build(owner, EventType.EVENT_TYPE_RESOURCE_CREATED,
            _resource('r-4'),
            createdAtMs: kNow),
        await _build(observer, EventType.EVENT_TYPE_RESOURCE_CONFIRMED,
            _obs('r-4', ObservationBody_Kind.KIND_CONFIRMED),
            createdAtMs: kNow),
        await _build(observer, EventType.EVENT_TYPE_RESOURCE_DISPUTED,
            _obs('r-4', ObservationBody_Kind.KIND_DISPUTED),
            createdAtMs: kNow),
      ];
      final TrustEngine engine =
          TrustEngine.fromEvents(log, roots: TrustRootStore());
      final TrustProfile p =
          engine.profileForResource('r-4', log, nowMs: kNow);
      expect(p.corroboration.confirmCount, 0);
      expect(p.corroboration.disputeCount, 1);
    });
  });

  group('freshness ranking', () {
    test('a 9-hour-old observation ranks below a 3-minute-old one', () async {
      final KeyPairData ownerFresh = await signer.generateKeyPair();
      final KeyPairData ownerStale = await signer.generateKeyPair();
      final int threeMinAgo = kNow - 3 * 60 * 1000;
      final int nineHrAgo = kNow - 9 * 60 * 60 * 1000;

      final List<SignedEvent> log = <SignedEvent>[
        await _build(ownerFresh, EventType.EVENT_TYPE_RESOURCE_CREATED,
            _resource('fresh'),
            createdAtMs: threeMinAgo),
        await _build(ownerStale, EventType.EVENT_TYPE_RESOURCE_CREATED,
            _resource('stale'),
            createdAtMs: nineHrAgo),
      ];
      // Each gets one confirm from a distinct observer, at matching ages.
      final KeyPairData o1 = await signer.generateKeyPair();
      final KeyPairData o2 = await signer.generateKeyPair();
      log.add(await _build(o1, EventType.EVENT_TYPE_RESOURCE_CONFIRMED,
          _obs('fresh', ObservationBody_Kind.KIND_CONFIRMED),
          createdAtMs: threeMinAgo));
      log.add(await _build(o2, EventType.EVENT_TYPE_RESOURCE_CONFIRMED,
          _obs('stale', ObservationBody_Kind.KIND_CONFIRMED),
          createdAtMs: nineHrAgo));

      final TrustEngine engine =
          TrustEngine.fromEvents(log, roots: TrustRootStore());
      final TrustProfile fresh =
          engine.profileForResource('fresh', log, nowMs: kNow);
      final TrustProfile stale =
          engine.profileForResource('stale', log, nowMs: kNow);

      expect(fresh.freshness.decayFactor,
          greaterThan(stale.freshness.decayFactor));
      expect(fresh.rankScore, greaterThan(stale.rankScore));

      final WorldState world = WorldState(clock: () => kNow);
      world.rebuildFromEvents(log);
      final List<String> order =
          world.rankedResources().map((ResourceView r) => r.resourceId).toList();
      expect(order.indexOf('fresh'), lessThan(order.indexOf('stale')));
      // Both present.
      expect(order, containsAll(<String>['fresh', 'stale']));
    });
  });

  group('source / verified-org', () {
    test('verified-org author chains to a seeded root => VERIFIED_ORG, '
        'revocation falls back to COMMUNITY + flagged', () async {
      final KeyPairData root = await signer.generateKeyPair();
      final KeyPairData responder = await signer.generateKeyPair();

      final TrustRootStore roots =
          TrustRootStore(seed: <List<int>>[root.publicKey]);

      // Root issues an org certificate for the responder.
      final SignedEvent cert = await _build(
        root,
        EventType.EVENT_TYPE_ORG_CERTIFICATE,
        OrgCertificateBody(
          orgRootPubkey: root.publicKey,
          subjectPubkey: responder.publicKey,
          orgName: 'Red Cross',
          provenance: ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG,
        ),
        createdAtMs: kNow,
      );

      final SignedEvent resource = await _build(
        responder,
        EventType.EVENT_TYPE_RESOURCE_CREATED,
        _resource('clinic',
            provenance: ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG),
        createdAtMs: kNow,
      );

      final List<SignedEvent> log = <SignedEvent>[cert, resource];
      final TrustEngine engine = TrustEngine.fromEvents(log, roots: roots);
      final TrustProfile p =
          engine.profileForResource('clinic', log, nowMs: kNow);
      expect(p.source.kind, ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG);
      expect(p.source.isVerifiedOrg, isTrue);
      expect(p.source.revoked, isFalse);

      // Now the root revokes the responder's key.
      final SignedEvent revoke = await _build(
        root,
        EventType.EVENT_TYPE_KEY_REVOKED,
        KeyRevokedBody(
          revokedPubkey: responder.publicKey,
          reason: 'device compromised',
          revokedAtMs: Int64(kNow),
        ),
        createdAtMs: kNow,
      );
      final List<SignedEvent> log2 = <SignedEvent>[cert, resource, revoke];
      final TrustEngine engine2 =
          TrustEngine.fromEvents(log2, roots: roots);
      final TrustProfile p2 =
          engine2.profileForResource('clinic', log2, nowMs: kNow);
      expect(p2.source.kind, ProvenanceKind.PROVENANCE_KIND_COMMUNITY);
      expect(p2.source.isVerifiedOrg, isFalse);
      // Flagged: was verified, now revoked.
      expect(p2.source.revoked, isTrue);
    });
  });
}
