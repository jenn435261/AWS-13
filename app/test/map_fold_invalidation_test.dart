import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/location/position_service.dart';
import 'package:resilience/state/derived_state.dart';

late Signer signer;
late EventFactory factory;
late LamportClock clock;

const int kNow = 1000000000000;

Future<SignedEvent> _build(
  KeyPairData author,
  EventType type,
  dynamic body,
) {
  return factory.buildFromMessage(
    keyPair: author,
    clock: clock,
    type: type,
    body: body,
    createdAtMs: Int64(kNow),
  );
}

void main() {
  setUp(() {
    signer = Signer();
    factory = EventFactory(signer: signer);
    clock = LamportClock();
  });

  test(
      'map read-model reflects a supply going out of stock via incremental '
      'fold (proves invalidation, not provider reconstruction)', () async {
    final KeyPairData owner = await signer.generateKeyPair();

    // The SAME WorldState instance is used throughout: if mapResources()
    // updates after applyEvent() without us rebuilding from scratch, the fold
    // invalidation path is correct (which is what drives worldRevisionProvider
    // / worldStateProvider in the app).
    final WorldState world = WorldState(clock: () => kNow);

    // 1) A bottled-water supply is created, in stock.
    final created = await _build(
      owner,
      EventType.EVENT_TYPE_RESOURCE_CREATED,
      ResourceBody(
        resourceId: 'water-1',
        category: ResourceCategory.RESOURCE_CATEGORY_WATER,
        title: 'Bottled water',
        amount: AmountBand.AMOUNT_BAND_PLENTY,
        availability: Availability.AVAILABILITY_NOW,
        provenance: ProvenanceKind.PROVENANCE_KIND_COMMUNITY,
        location: geoPointFor(const LatLng(37.3, -121.9)),
      ),
    );
    world.applyEvent(created);

    final snap = await _build(
      owner,
      EventType.EVENT_TYPE_INVENTORY_SNAPSHOT,
      InventorySnapshotBody(
        resourceId: 'water-1',
        quantity: Int64(24),
        unit: 'bottles',
        asOfMs: Int64(kNow),
      ),
    );
    world.applyEvent(snap);

    // Present on the map, in stock.
    var onMap = world.mapResources();
    expect(onMap.map((r) => r.resourceId), contains('water-1'));
    final present = onMap.firstWhere((r) => r.resourceId == 'water-1');
    expect(present.availableQuantity, 24);
    expect(present.resource.amount, AmountBand.AMOUNT_BAND_PLENTY);

    // 2) Owner marks it out of stock: snapshot qty 0 + RESOURCE_UPDATED LOW.
    world.applyEvent(await _build(
      owner,
      EventType.EVENT_TYPE_INVENTORY_SNAPSHOT,
      InventorySnapshotBody(
        resourceId: 'water-1',
        quantity: Int64(0),
        unit: 'bottles',
        asOfMs: Int64(kNow + 1),
      ),
    ));
    world.applyEvent(await _build(
      owner,
      EventType.EVENT_TYPE_RESOURCE_UPDATED,
      ResourceUpdateBody(
        resourceId: 'water-1',
        amount: AmountBand.AMOUNT_BAND_LOW,
      ),
    ));

    // The SAME WorldState now reflects out-of-stock on its map read-model,
    // without re-constructing the projection from a fresh instance.
    onMap = world.mapResources();
    final after = onMap.firstWhere((r) => r.resourceId == 'water-1');
    expect(after.availableQuantity, 0, reason: 'snapshot qty 0 folded in');
    expect(after.resource.amount, AmountBand.AMOUNT_BAND_LOW,
        reason: 'RESOURCE_UPDATED amount folded in');
  });

  test('a non-owner cannot move another author\'s request pin', () async {
    final KeyPairData owner = await signer.generateKeyPair();
    final KeyPairData attacker = await signer.generateKeyPair();

    final world = WorldState(clock: () => kNow);

    // Owner creates a request at point A.
    world.applyEvent(await _build(
      owner,
      EventType.EVENT_TYPE_HELP_REQUESTED,
      HelpRequestBody(
        requestId: 'req-1',
        categories: [ResourceCategory.RESOURCE_CATEGORY_WATER],
        freeform: 'need water',
        location: geoPointFor(const LatLng(37.30, -121.90)),
      ),
    ));

    // Attacker tries to re-publish the SAME request id at point B.
    world.applyEvent(await _build(
      attacker,
      EventType.EVENT_TYPE_HELP_REQUESTED,
      HelpRequestBody(
        requestId: 'req-1',
        categories: [ResourceCategory.RESOURCE_CATEGORY_WATER],
        freeform: 'hijacked',
        location: geoPointFor(const LatLng(40.0, -70.0)),
      ),
    ));

    final req = world.helpRequests.firstWhere((q) => q.requestId == 'req-1');
    // Ownership + position stay with the first author; the hijack is ignored.
    expect(req.body.freeform, 'need water');
    final pt = latLngOf(req.body.location)!;
    expect(pt.latitude, 37.3);
    expect(pt.longitude, -121.9);

    // The real owner CAN move their own pin by re-publishing the same id.
    world.applyEvent(await _build(
      owner,
      EventType.EVENT_TYPE_HELP_REQUESTED,
      HelpRequestBody(
        requestId: 'req-1',
        categories: [ResourceCategory.RESOURCE_CATEGORY_WATER],
        freeform: 'need water',
        location: geoPointFor(const LatLng(37.35, -121.95)),
      ),
    ));
    final moved = world.helpRequests.firstWhere((q) => q.requestId == 'req-1');
    final movedPt = latLngOf(moved.body.location)!;
    expect(movedPt.latitude, 37.35);
    expect(movedPt.longitude, -121.95);
  });
}
