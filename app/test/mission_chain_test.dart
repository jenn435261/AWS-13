import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/logistics/capabilities.dart';
import 'package:resilience/logistics/mission.dart';
import 'package:resilience/logistics/package_chain.dart';

void main() {
  late Signer signer;
  late EventFactory factory;
  late MissionEvents missionEvents;
  late PackageEvents packageEvents;

  late KeyPairData source; // pickup site
  late KeyPairData driverA;
  late KeyPairData driverB;
  late KeyPairData shelter; // recipient

  const String missionId = '2193';
  const String packageId = 'pkg-8192';

  setUp(() async {
    signer = Signer();
    factory = EventFactory(signer: signer);
    missionEvents = MissionEvents(factory: factory);
    packageEvents = PackageEvents(factory: factory);
    source = await signer.generateKeyPair();
    driverA = await signer.generateKeyPair();
    driverB = await signer.generateKeyPair();
    shelter = await signer.generateKeyPair();
  });

  test('full pipeline builds a valid, signed 4-hop custody chain', () async {
    final clock = LamportClock();

    // MISSION_CREATED by source.
    final created = await missionEvents.created(
      creatorKeyPair: source,
      clock: clock,
      missionId: missionId,
      cargoCategory: ResourceCategory.RESOURCE_CATEGORY_WATER,
      cargoQuantity: 10,
      pickupName: 'Warehouse',
      destinationName: 'Shelter',
    );

    // MISSION_ACCEPTED by driver A.
    final accepted = await missionEvents.accepted(
      carrierKeyPair: driverA,
      clock: clock,
      missionId: missionId,
    );

    // PICKED_UP: driver A picks up from source.
    final pickedUp = await packageEvents.pickedUp(
      actorKeyPair: driverA,
      clock: clock,
      packageId: packageId,
      missionId: missionId,
      counterparty: source.publicKey,
      atMs: 1000,
    );

    // HANDOFF A -> B: A transfers, B receives.
    final transferOut = await packageEvents.transferred(
      actorKeyPair: driverA,
      clock: clock,
      packageId: packageId,
      missionId: missionId,
      counterparty: driverB.publicKey,
      atMs: 2000,
    );
    final transferIn = await packageEvents.transferred(
      actorKeyPair: driverB,
      clock: clock,
      packageId: packageId,
      missionId: missionId,
      counterparty: driverA.publicKey,
      atMs: 2001,
    );

    // DELIVERY_COMPLETED: recipient at shelter, signed by the final custodian
    // (driver B).
    final delivered = await packageEvents.delivered(
      actorKeyPair: driverB,
      clock: clock,
      packageId: packageId,
      missionId: missionId,
      counterparty: shelter.publicKey,
      atMs: 3000,
    );

    final allEvents = <SignedEvent>[
      created,
      accepted,
      pickedUp,
      transferOut,
      transferIn,
      delivered,
    ];

    final chain = await PackageChain.fromEvents(
      packageId: packageId,
      events: allEvents,
      factory: factory,
    );

    expect(chain.isValid, isTrue, reason: chain.invalidReason);
    expect(chain.delivered, isTrue);
    expect(chain.handoffsConfirmed, 1);

    // 4-hop audit trail: pickup, handoff, delivery (source->A->B->shelter).
    expect(chain.hops.length, 3);
    expect(chain.hops[0].stage, PackageEventBody_Stage.STAGE_PICKED_UP);
    expect(chain.hops[1].stage, PackageEventBody_Stage.STAGE_TRANSFERRED);
    expect(chain.hops[2].stage, PackageEventBody_Stage.STAGE_DELIVERED);

    // Custody actors in order: A (pickup), A->B (handoff), B (delivery).
    expect(chain.hops[0].actor, equals(Uint8List.fromList(driverA.publicKey)));
    expect(chain.hops[0].counterparty,
        equals(Uint8List.fromList(source.publicKey)));
    expect(chain.hops[1].actor, equals(Uint8List.fromList(driverA.publicKey)));
    expect(chain.hops[1].counterparty,
        equals(Uint8List.fromList(driverB.publicKey)));
    expect(chain.hops[2].actor, equals(Uint8List.fromList(driverB.publicKey)));
    expect(chain.hops[2].counterparty,
        equals(Uint8List.fromList(shelter.publicKey)));
  });

  test('a chain with a missing receive link fails validation', () async {
    final clock = LamportClock();
    final pickedUp = await packageEvents.pickedUp(
      actorKeyPair: driverA,
      clock: clock,
      packageId: packageId,
      missionId: missionId,
      counterparty: source.publicKey,
      atMs: 1000,
    );
    // A transfers to B, but B never signs the receive => unconfirmed handoff.
    final transferOut = await packageEvents.transferred(
      actorKeyPair: driverA,
      clock: clock,
      packageId: packageId,
      missionId: missionId,
      counterparty: driverB.publicKey,
      atMs: 2000,
    );

    final chain = await PackageChain.fromEvents(
      packageId: packageId,
      events: <SignedEvent>[pickedUp, transferOut],
      factory: factory,
    );

    expect(chain.isValid, isFalse);
  });

  test('a chain with a forged signature fails validation', () async {
    final clock = LamportClock();
    final pickedUp = await packageEvents.pickedUp(
      actorKeyPair: driverA,
      clock: clock,
      packageId: packageId,
      missionId: missionId,
      counterparty: source.publicKey,
      atMs: 1000,
    );

    // Tamper with the signature => the chain must reject it.
    final forged = pickedUp.deepCopy();
    final sig = Uint8List.fromList(forged.signature);
    sig[0] ^= 0xFF;
    forged.signature = sig;

    final chain = await PackageChain.fromEvents(
      packageId: packageId,
      events: <SignedEvent>[forged],
      factory: factory,
    );

    expect(chain.isValid, isFalse);
    expect(chain.invalidReason, contains('forged'));
  });

  test('MissionStore shows completed status after delivery to a party viewer',
      () async {
    final clock = LamportClock();
    final created = await missionEvents.created(
      creatorKeyPair: source,
      clock: clock,
      missionId: missionId,
      cargoCategory: ResourceCategory.RESOURCE_CATEGORY_WATER,
      pickupLocation: GeoPoint(
        exactLat: 37.77493,
        exactLon: -122.41942,
        address: '742 Example St, rear entrance',
        hasExact: true,
        h3Cell: Int64(1234),
      ),
    );
    final accepted = await missionEvents.accepted(
      carrierKeyPair: driverA,
      clock: clock,
      missionId: missionId,
    );
    final pickedUp = await packageEvents.pickedUp(
      actorKeyPair: driverA,
      clock: clock,
      packageId: missionId,
      missionId: missionId,
      counterparty: source.publicKey,
      atMs: 1000,
    );
    final delivered = await packageEvents.delivered(
      actorKeyPair: driverA,
      clock: clock,
      packageId: missionId,
      missionId: missionId,
      counterparty: shelter.publicKey,
      atMs: 2000,
    );

    final store = MissionStore(factory: factory);
    final views = await store.missionsForViewer(
      viewerPubkey: source.publicKey, // creator is a party
      capabilities: CapabilitySet(<String, Capability>{}),
      events: [created, accepted, pickedUp, delivered],
    );

    expect(views, hasLength(1));
    expect(views.first.status, MissionStatus.completed);
    // Creator is a party => sees exact pickup.
    expect(views.first.pickup.hasExactAccess, isTrue);
    expect(views.first.pickup.point.address, '742 Example St, rear entrance');
  });
}
