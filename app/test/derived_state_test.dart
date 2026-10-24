import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/state/derived_state.dart';
import 'package:resilience/trust/trust_roots.dart';

late Signer signer;
late EventFactory factory;
late LamportClock clock;

const int kNow = 1000000000000;

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

ResourceBody _resource(String id) => ResourceBody(
      resourceId: id,
      category: ResourceCategory.RESOURCE_CATEGORY_WATER,
      title: 'Water $id',
      amount: AmountBand.AMOUNT_BAND_PLENTY,
      availability: Availability.AVAILABILITY_NOW,
      provenance: ProvenanceKind.PROVENANCE_KIND_COMMUNITY,
    );

void main() {
  setUp(() {
    signer = Signer();
    factory = EventFactory(signer: signer);
    clock = LamportClock();
  });

  test('RESOURCE_CREATED then RESOURCE_UPDATED(amount low) reflects latest',
      () async {
    final KeyPairData owner = await signer.generateKeyPair();
    final List<SignedEvent> log = <SignedEvent>[
      await _build(
          owner, EventType.EVENT_TYPE_RESOURCE_CREATED, _resource('r-1'),
          createdAtMs: kNow),
      await _build(
          owner,
          EventType.EVENT_TYPE_RESOURCE_UPDATED,
          ResourceUpdateBody(
            resourceId: 'r-1',
            amount: AmountBand.AMOUNT_BAND_LOW,
          ),
          createdAtMs: kNow),
    ];

    final WorldState world = WorldState(clock: () => kNow);
    world.rebuildFromEvents(log);

    final ResourceView? view = world.resources['r-1'];
    expect(view, isNotNull);
    expect(view!.resource.amount, AmountBand.AMOUNT_BAND_LOW);
    expect(view.withdrawn, isFalse);
  });

  test('RESOURCE_UPDATED(withdrawn=true) marks withdrawn but keeps present',
      () async {
    final KeyPairData owner = await signer.generateKeyPair();
    final List<SignedEvent> log = <SignedEvent>[
      await _build(
          owner, EventType.EVENT_TYPE_RESOURCE_CREATED, _resource('r-2'),
          createdAtMs: kNow),
      await _build(
          owner,
          EventType.EVENT_TYPE_RESOURCE_UPDATED,
          ResourceUpdateBody(resourceId: 'r-2', withdrawn: true),
          createdAtMs: kNow),
    ];

    final WorldState world = WorldState(clock: () => kNow);
    world.rebuildFromEvents(log);

    final ResourceView? view = world.resources['r-2'];
    expect(view, isNotNull);
    expect(view!.withdrawn, isTrue);
    // Still present in ranked output.
    expect(world.rankedResources().map((ResourceView r) => r.resourceId),
        contains('r-2'));
  });

  test(
      'INVENTORY_SNAPSHOT(43) + community observations stay authoritative; '
      'RESERVATION(20) => available 23', () async {
    final KeyPairData owner = await signer.generateKeyPair();
    final KeyPairData neighbor1 = await signer.generateKeyPair();
    final KeyPairData neighbor2 = await signer.generateKeyPair();

    final List<SignedEvent> log = <SignedEvent>[
      await _build(
          owner, EventType.EVENT_TYPE_RESOURCE_CREATED, _resource('water'),
          createdAtMs: kNow),
      await _build(
          owner,
          EventType.EVENT_TYPE_INVENTORY_SNAPSHOT,
          InventorySnapshotBody(
            resourceId: 'water',
            quantity: Int64(43),
            unit: 'bottles',
            asOfMs: Int64(kNow),
          ),
          createdAtMs: kNow),
      // Community observations annotate ("low") but must not change the number.
      await _build(
          neighbor1,
          EventType.EVENT_TYPE_RESOURCE_OBSERVED,
          ObservationBody(
            resourceId: 'water',
            kind: ObservationBody_Kind.KIND_OBSERVED,
            note: 'low',
            observedAmount: AmountBand.AMOUNT_BAND_LOW,
          ),
          createdAtMs: kNow),
      await _build(
          neighbor2,
          EventType.EVENT_TYPE_RESOURCE_OBSERVED,
          ObservationBody(
            resourceId: 'water',
            kind: ObservationBody_Kind.KIND_OBSERVED,
            note: 'almost empty',
            observedAmount: AmountBand.AMOUNT_BAND_LOW,
          ),
          createdAtMs: kNow),
      // Owner-signed reservation of 20.
      await _build(
          owner,
          EventType.EVENT_TYPE_RESERVATION,
          ReservationBody(
            resourceId: 'water',
            quantity: Int64(20),
            missionId: 'm-1',
          ),
          createdAtMs: kNow),
    ];

    final WorldState world = WorldState(clock: () => kNow);
    world.rebuildFromEvents(log);

    final ResourceView view = world.resources['water']!;
    // Authoritative number is unchanged by community observations.
    expect(view.inventory, isNotNull);
    expect(view.inventory!.quantity, 43);
    expect(view.inventory!.unit, 'bottles');
    // Observations attached.
    expect(view.observations.length, 2);
    expect(view.observations.map((ObservationView o) => o.note),
        containsAll(<String>['low', 'almost empty']));
    // Reservation reduces available, not authoritative.
    expect(view.reservedQuantity, 20);
    expect(view.availableQuantity, 23);
  });

  test('rankedResources: confirmed+fresh+verified before lone stale, both present',
      () async {
    final KeyPairData root = await signer.generateKeyPair();
    final KeyPairData responder = await signer.generateKeyPair();
    final KeyPairData loner = await signer.generateKeyPair();

    final TrustRootStore roots =
        TrustRootStore(seed: <List<int>>[root.publicKey]);

    final int nineHrAgo = kNow - 9 * 60 * 60 * 1000;

    final List<SignedEvent> log = <SignedEvent>[
      // Verified-org, fresh, highly confirmed resource.
      await _build(
          root,
          EventType.EVENT_TYPE_ORG_CERTIFICATE,
          OrgCertificateBody(
            orgRootPubkey: root.publicKey,
            subjectPubkey: responder.publicKey,
            orgName: 'FEMA',
            provenance: ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG,
          ),
          createdAtMs: kNow),
      await _build(
          responder, EventType.EVENT_TYPE_RESOURCE_CREATED, _resource('good'),
          createdAtMs: kNow),
      // Lone, stale, unconfirmed report.
      await _build(
          loner, EventType.EVENT_TYPE_RESOURCE_CREATED, _resource('weak'),
          createdAtMs: nineHrAgo),
    ];
    for (int i = 0; i < 5; i++) {
      final KeyPairData obs = await signer.generateKeyPair();
      log.add(await _build(
          obs,
          EventType.EVENT_TYPE_RESOURCE_CONFIRMED,
          ObservationBody(
            resourceId: 'good',
            kind: ObservationBody_Kind.KIND_CONFIRMED,
          ),
          createdAtMs: kNow));
    }

    final WorldState world =
        WorldState(trustRoots: roots, clock: () => kNow);
    world.rebuildFromEvents(log);

    final List<String> order =
        world.rankedResources().map((ResourceView r) => r.resourceId).toList();
    expect(order.indexOf('good'), lessThan(order.indexOf('weak')));
    expect(order, containsAll(<String>['good', 'weak']));
  });

  test('HELP_REQUEST_CLOSED by the owner closes the request (owner-only)',
      () async {
    final KeyPairData owner = await signer.generateKeyPair();
    final List<SignedEvent> log = <SignedEvent>[
      await _build(
          owner,
          EventType.EVENT_TYPE_HELP_REQUESTED,
          HelpRequestBody(requestId: 'req-1', freeform: 'Need water'),
          createdAtMs: kNow),
    ];

    final WorldState open = WorldState(clock: () => kNow);
    open.rebuildFromEvents(log);
    expect(open.helpRequests.single.closed, isFalse);

    log.add(await _build(
        owner,
        EventType.EVENT_TYPE_HELP_REQUEST_CLOSED,
        HelpRequestClosedBody(requestId: 'req-1', reason: 'resolved'),
        createdAtMs: kNow));

    final WorldState closed = WorldState(clock: () => kNow);
    closed.rebuildFromEvents(log);
    expect(closed.helpRequests.single.closed, isTrue);
    expect(closed.helpRequests.single.closeReason, 'resolved');
  });

  test('a HELP_REQUEST_CLOSED from a non-owner is ignored (abuse)', () async {
    final KeyPairData owner = await signer.generateKeyPair();
    final KeyPairData attacker = await signer.generateKeyPair();
    final List<SignedEvent> log = <SignedEvent>[
      await _build(
          owner,
          EventType.EVENT_TYPE_HELP_REQUESTED,
          HelpRequestBody(requestId: 'req-2', freeform: 'Need meds'),
          createdAtMs: kNow),
      // A different key tries to close someone else's request.
      await _build(
          attacker,
          EventType.EVENT_TYPE_HELP_REQUEST_CLOSED,
          HelpRequestClosedBody(requestId: 'req-2'),
          createdAtMs: kNow),
    ];

    final WorldState world = WorldState(clock: () => kNow);
    world.rebuildFromEvents(log);
    expect(world.helpRequests.single.closed, isFalse,
        reason: 'only the author may close a request');
  });

  test('alert recall: re-issuing the same alert_id with past expiry hides it; '
      'only the author may recall', () async {
    final KeyPairData root = await signer.generateKeyPair();
    final KeyPairData otherOrg = await signer.generateKeyPair();
    final TrustRootStore roots = TrustRootStore(
        seed: <List<int>>[root.publicKey, otherOrg.publicKey]);

    final List<SignedEvent> log = <SignedEvent>[
      await _build(
          root,
          EventType.EVENT_TYPE_EMERGENCY_ALERT,
          EmergencyAlertBody(
              alertId: 'al-1',
              title: 'Boil water',
              expiresMs: Int64(kNow + 3600 * 1000)),
          createdAtMs: kNow),
    ];
    final WorldState shown = WorldState(trustRoots: roots, clock: () => kNow);
    shown.rebuildFromEvents(log);
    expect(shown.emergencyAlerts.single.body.title, 'Boil water');

    // A DIFFERENT verified org cannot recall someone else's alert.
    log.add(await _build(
        otherOrg,
        EventType.EVENT_TYPE_EMERGENCY_ALERT,
        EmergencyAlertBody(
            alertId: 'al-1', title: 'hijack', expiresMs: Int64(kNow - 1000)),
        createdAtMs: kNow));
    final WorldState stillShown =
        WorldState(trustRoots: roots, clock: () => kNow);
    stillShown.rebuildFromEvents(log);
    expect(stillShown.emergencyAlerts.single.body.title, 'Boil water',
        reason: 'a non-author cannot recall or alter the alert');

    // The ORIGINAL author recalls by re-issuing with expires in the past.
    log.add(await _build(
        root,
        EventType.EVENT_TYPE_EMERGENCY_ALERT,
        EmergencyAlertBody(
            alertId: 'al-1', title: 'Boil water', expiresMs: Int64(kNow - 1000)),
        createdAtMs: kNow));
    final WorldState recalled =
        WorldState(trustRoots: roots, clock: () => kNow);
    recalled.rebuildFromEvents(log);
    expect(recalled.emergencyAlerts, isEmpty,
        reason: 'a recalled (past-expiry) alert is not shown');
  });

  test('a supply past available_until_ms is auto-hidden from the map but '
      'stays in the projection', () async {
    final KeyPairData owner = await signer.generateKeyPair();
    final ResourceBody expiring = _resource('exp')
      ..availableUntilMs = Int64(kNow - 1000); // already past
    final ResourceBody live = _resource('live')
      ..availableUntilMs = Int64(kNow + 3600 * 1000);

    final List<SignedEvent> log = <SignedEvent>[
      await _build(owner, EventType.EVENT_TYPE_RESOURCE_CREATED, expiring,
          createdAtMs: kNow),
      await _build(owner, EventType.EVENT_TYPE_RESOURCE_CREATED, live,
          createdAtMs: kNow),
    ];

    final WorldState world = WorldState(clock: () => kNow);
    world.rebuildFromEvents(log);

    // Both are still present (owner's My Supplies shows the expired one).
    expect(world.resources.containsKey('exp'), isTrue);
    expect(world.resources['exp']!.isExpired(kNow), isTrue);
    // The map excludes the expired supply.
    final mapIds =
        world.mapResources().map((ResourceView r) => r.resourceId).toSet();
    expect(mapIds, contains('live'));
    expect(mapIds, isNot(contains('exp')));
  });

  test('certificate chain depth limit: depth 2 verifies, depth 3 does not',
      () async {
    final KeyPairData root = await signer.generateKeyPair();
    final KeyPairData a = await signer.generateKeyPair(); // depth 1
    final KeyPairData b = await signer.generateKeyPair(); // depth 2
    final KeyPairData c = await signer.generateKeyPair(); // depth 3
    final TrustRootStore roots =
        TrustRootStore(seed: <List<int>>[root.publicKey]);

    Future<SignedEvent> cert(KeyPairData issuer, KeyPairData subject) => _build(
          issuer,
          EventType.EVENT_TYPE_ORG_CERTIFICATE,
          OrgCertificateBody(
            orgRootPubkey: issuer.publicKey,
            subjectPubkey: subject.publicKey,
            provenance: ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG,
          ),
          createdAtMs: kNow,
        );

    final List<SignedEvent> log = <SignedEvent>[
      await cert(root, a), // root -> a  (a is depth 1)
      await cert(a, b), //    a -> b     (b is depth 2)
      await cert(b, c), //    b -> c     (c is depth 3)
    ];

    final WorldState world = WorldState(trustRoots: roots, clock: () => kNow);
    world.rebuildFromEvents(log);

    expect(world.provenanceOf(a.publicKey),
        ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG,
        reason: 'depth 1 is within the limit');
    expect(world.provenanceOf(b.publicKey),
        ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG,
        reason: 'depth 2 is the limit and still verifies');
    expect(world.provenanceOf(c.publicKey),
        ProvenanceKind.PROVENANCE_KIND_COMMUNITY,
        reason: 'depth 3 exceeds the limit and grants no badge');
  });

  test('applyEvent incrementally updates the projection', () async {
    final KeyPairData owner = await signer.generateKeyPair();
    final WorldState world = WorldState(clock: () => kNow);

    final SignedEvent created = await _build(
        owner, EventType.EVENT_TYPE_RESOURCE_CREATED, _resource('inc'),
        createdAtMs: kNow);
    world.applyEvent(created);
    expect(world.resources['inc']!.resource.amount,
        AmountBand.AMOUNT_BAND_PLENTY);

    final SignedEvent updated = await _build(
        owner,
        EventType.EVENT_TYPE_RESOURCE_UPDATED,
        ResourceUpdateBody(resourceId: 'inc', amount: AmountBand.AMOUNT_BAND_LOW),
        createdAtMs: kNow);
    world.applyEvent(updated);
    expect(
        world.resources['inc']!.resource.amount, AmountBand.AMOUNT_BAND_LOW);
  });
}
