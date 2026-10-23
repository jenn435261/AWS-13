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
