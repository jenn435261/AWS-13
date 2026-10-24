import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/location/location_share.dart';
import 'package:resilience/logistics/location_view.dart';
import 'package:resilience/state/derived_state.dart';

void main() {
  GeoPoint fullPoint() => GeoPoint(
        h3Cell: Int64(0x8928308280fffff),
        approxLat: 37.77,
        approxLon: -122.42,
        exactLat: 37.774929,
        exactLon: -122.419418,
        hasExact: true,
        address: '742 Example St, rear entrance',
      );

  test('public viewer gets only approximate; exact is stripped', () {
    final view = LocationView.resolve(fullPoint(), hasExactAccess: false);

    expect(view.hasExactAccess, isFalse);
    // Exact fields are gone.
    expect(view.point.hasExactLat(), isFalse);
    expect(view.point.hasExactLon(), isFalse);
    expect(view.point.hasAddress(), isFalse);
    expect(view.point.hasExact, isFalse);
    // Coarse + approx survive.
    expect(view.point.hasH3Cell(), isTrue);
    expect(view.point.approxLat, 37.77);
    expect(view.point.approxLon, -122.42);

    final desc = view.describe(fromLat: 37.78, fromLon: -122.43);
    expect(desc, contains('~'));
    expect(desc, contains('miles away'));
    // Never leaks the exact coordinate string.
    expect(desc.contains('37.774929'), isFalse);
    expect(desc.contains('742 Example St'), isFalse);
  });

  test('a capability holder (exact access) gets exact coords + address', () {
    final view = LocationView.resolve(fullPoint(), hasExactAccess: true);

    expect(view.hasExactAccess, isTrue);
    expect(view.point.exactLat, 37.774929);
    expect(view.point.exactLon, -122.419418);
    expect(view.point.address, '742 Example St, rear entrance');
    expect(view.describe(), '742 Example St, rear entrance');
  });

  test('publicProjection never leaks exact coords even without an approx', () {
    final exactOnly = GeoPoint(
      exactLat: 37.774929,
      exactLon: -122.419418,
      hasExact: true,
      address: 'secret dock',
    );
    final projected = publicProjection(exactOnly);

    expect(projected.hasExactLat(), isFalse);
    expect(projected.hasExactLon(), isFalse);
    expect(projected.hasAddress(), isFalse);
    // An approximate is derived (rounded) so the viewer still gets a bucket,
    // but it is NOT the exact value.
    expect(projected.hasApproxLat(), isTrue);
    expect(projected.approxLat, isNot(37.774929));
    expect(projected.approxLon, isNot(-122.419418));
  });

  test('roundApprox coarsens a coordinate to the grid', () {
    expect(roundApprox(37.774929), 37.77);
    expect(roundApprox(-122.419418), -122.42);
    // Reducing precision guarantees the exact value is never recoverable.
    expect(roundApprox(37.774929) == 37.774929, isFalse);
  });

  group('WorldState.locationSharesVisibleTo scoping', () {
    late Signer signer;

    setUp(() => signer = Signer());

    test('public beacon is visible to any viewer; a contact share is not',
        () async {
      final sharer = await signer.generateKeyPair();
      final viewer = await signer.generateKeyPair();
      final factory = EventFactory(signer: signer);
      final shareClock = LamportClock();
      final at = DateTime.utc(2024, 6, 1, 9);

      final ls = LocationSharer(
        selfKeyPair: sharer,
        clock: shareClock,
        factory: factory,
        now: () => at,
      );

      // A public beacon (coarse, in the clear).
      final beacon = await ls.broadcastPublicBeacon(
        GeoPoint(approxLat: 37.33, approxLon: -121.88),
        ttl: const Duration(hours: 1),
        shareId: 'beacon-1',
      );

      final world = WorldState(
          clock: () => at.millisecondsSinceEpoch + 1000);
      world.rebuildFromEvents([beacon]);

      // Public beacons are visible to everyone by default.
      final visible = world.locationSharesVisibleTo(viewer.publicKey);
      expect(visible.map((s) => s.shareId), contains('beacon-1'));
      expect(visible.first.isPublic, isTrue);

      // With public beacons excluded, the viewer (not the audience of any
      // contact share) sees nothing.
      final noPublic = world.locationSharesVisibleTo(
        viewer.publicKey,
        includePublic: false,
      );
      expect(noPublic, isEmpty);
    });

    test('a channel share is only visible to a viewer in that channel',
        () async {
      final sharer = await signer.generateKeyPair();
      final viewer = await signer.generateKeyPair();
      final factory = EventFactory(signer: signer);
      final at = DateTime.utc(2024, 6, 1, 9);

      // Build a channel LOCATION_SHARE event by hand (encryptedPoint opaque).
      final body = LocationShareBody(
        shareId: 'chan-1',
        scope: 'channel:rescue-7',
        encryptedPoint: Uint8List.fromList([1, 2, 3, 4]),
        expiresMs:
            Int64(at.add(const Duration(hours: 1)).millisecondsSinceEpoch),
        seq: Int64(1),
      );
      final ev = await factory.buildFromMessage(
        keyPair: sharer,
        clock: LamportClock(),
        type: EventType.EVENT_TYPE_LOCATION_SHARE,
        body: body,
      );

      final world = WorldState(
          clock: () => at.millisecondsSinceEpoch + 1000);
      world.rebuildFromEvents([ev]);

      // Not in the channel -> not visible.
      expect(
        world.locationSharesVisibleTo(viewer.publicKey),
        isEmpty,
      );
      // In the channel -> visible.
      final inChannel = world.locationSharesVisibleTo(
        viewer.publicKey,
        channelIds: {'rescue-7'},
      );
      expect(inChannel.map((s) => s.shareId), contains('chan-1'));
    });
  });
}
