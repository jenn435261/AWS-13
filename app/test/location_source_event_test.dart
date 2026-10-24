import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/location/position_service.dart';

void main() {
  late Signer signer;
  late EventFactory factory;
  late LamportClock clock;

  setUp(() {
    signer = Signer();
    factory = EventFactory(signer: signer);
    clock = LamportClock();
  });

  test('location_source flows onto a HELP_REQUESTED event body', () async {
    final kp = await signer.generateKeyPair();
    final body = HelpRequestBody(
      requestId: 'r1',
      categories: [ResourceCategory.RESOURCE_CATEGORY_WATER],
      freeform: 'need water',
      location: geoPointFor(const LatLng(37.3382, -121.8863),
          source: LocationSource.LOCATION_SOURCE_MANUAL),
    );
    final ev = await factory.buildFromMessage(
      keyPair: kp,
      clock: clock,
      type: EventType.EVENT_TYPE_HELP_REQUESTED,
      body: body,
    );
    // Decode off the wire to prove it survives serialization.
    final decoded = HelpRequestBody.fromBuffer(ev.body);
    expect(decoded.location.locationSource,
        LocationSource.LOCATION_SOURCE_MANUAL);
    // Privacy: still rounded to ~110 m.
    expect(decoded.location.approxLat, 37.338);
    expect(decoded.location.approxLon, -121.886);
  });

  test('location_source flows onto a RESOURCE_CREATED (supply) body', () async {
    final kp = await signer.generateKeyPair();
    final body = ResourceBody(
      resourceId: 's1',
      category: ResourceCategory.RESOURCE_CATEGORY_WATER,
      title: 'Bottled water',
      location: geoPointFor(const LatLng(37.0, -121.0),
          source: LocationSource.LOCATION_SOURCE_LAST_KNOWN),
    );
    final ev = await factory.buildFromMessage(
      keyPair: kp,
      clock: clock,
      type: EventType.EVENT_TYPE_RESOURCE_CREATED,
      body: body,
    );
    final decoded = ResourceBody.fromBuffer(ev.body);
    expect(decoded.location.locationSource,
        LocationSource.LOCATION_SOURCE_LAST_KNOWN);
  });

  test('estimated source round-trips on a LOCATION_SHARE public point',
      () async {
    final kp = await signer.generateKeyPair();
    final body = LocationShareBody(
      shareId: 'sh1',
      scope: 'public',
      publicPoint: geoPointFor(const LatLng(37.0, -121.0),
          source: LocationSource.LOCATION_SOURCE_ESTIMATED),
    );
    final ev = await factory.buildFromMessage(
      keyPair: kp,
      clock: clock,
      type: EventType.EVENT_TYPE_LOCATION_SHARE,
      body: body,
    );
    final decoded = LocationShareBody.fromBuffer(ev.body);
    expect(decoded.publicPoint.locationSource,
        LocationSource.LOCATION_SOURCE_ESTIMATED);
  });
}
