import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:resilience/db/database.dart';
import 'package:resilience/db/json_store.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/location/last_fix_store.dart';
import 'package:resilience/location/position_service.dart';
import 'package:resilience/sync/connectivity.dart';

void main() {
  group('LastFix cache + age label', () {
    late AppDatabase db;
    late LastFixStore store;

    setUp(() {
      db = AppDatabase.memory();
      store = LastFixStore(JsonStore(db, 'loc:'));
    });

    tearDown(() => db.close());

    test('round-trips a fix through the KeyValue table', () async {
      expect(await store.read(), isNull);
      const fix = LastFix(
          lat: 37.3382012, lon: -121.8863456, accuracyM: 12.5, takenAtMs: 1000);
      await store.write(fix);
      final read = await store.read();
      expect(read, isNotNull);
      expect(read!.lat, closeTo(37.3382012, 1e-9));
      expect(read.lon, closeTo(-121.8863456, 1e-9));
      expect(read.accuracyM, 12.5);
      expect(read.takenAtMs, 1000);
    });

    test('clear removes the cached fix', () async {
      await store.write(const LastFix(lat: 1, lon: 2, takenAtMs: 1));
      await store.clear();
      expect(await store.read(), isNull);
    });

    test('age label is coarse and honest', () {
      const fix = LastFix(lat: 1, lon: 2, takenAtMs: 0);
      expect(fix.ageLabel(0), 'just now');
      expect(fix.ageLabel(30 * 1000), 'just now');
      expect(fix.ageLabel(2 * 60 * 1000), '2 min ago');
      expect(fix.ageLabel(90 * 60 * 1000), '1 hr ago');
      expect(fix.ageLabel(26 * 60 * 60 * 1000), '1 day ago');
      expect(fix.ageLabel(3 * 24 * 60 * 60 * 1000), '3 days ago');
      // A future timestamp never reads as a stale age.
      expect(fix.ageLabel(-5000), 'just now');
    });
  });

  group('geoPointFor location_source', () {
    test('defaults to unspecified, rounds to ~110m', () {
      final g = geoPointFor(const LatLng(37.3382012, -121.8863456));
      expect(g.approxLat, 37.338);
      expect(g.approxLon, -121.886);
      expect(g.hasLocationSource(), isFalse);
      expect(g.hasExact, isFalse);
    });

    test('carries the requested source onto the GeoPoint', () {
      final gps = geoPointFor(const LatLng(1, 2),
          source: LocationSource.LOCATION_SOURCE_GPS);
      expect(gps.locationSource, LocationSource.LOCATION_SOURCE_GPS);

      final manual = geoPointFor(const LatLng(1, 2),
          source: LocationSource.LOCATION_SOURCE_MANUAL);
      expect(manual.locationSource, LocationSource.LOCATION_SOURCE_MANUAL);

      final lastKnown = geoPointFor(const LatLng(1, 2),
          source: LocationSource.LOCATION_SOURCE_LAST_KNOWN);
      expect(lastKnown.locationSource,
          LocationSource.LOCATION_SOURCE_LAST_KNOWN);
    });
  });

  group('estimated uncertainty radius (dead-reckoning)', () {
    test('grows with distance walked', () {
      final near = estimatedUncertaintyRadiusM(
          baseAccuracyM: 30,
          distanceWalkedM: 100,
          elapsed: Duration.zero);
      final far = estimatedUncertaintyRadiusM(
          baseAccuracyM: 30,
          distanceWalkedM: 1000,
          elapsed: Duration.zero);
      expect(far, greaterThan(near));
    });

    test('grows with elapsed time', () {
      final fresh = estimatedUncertaintyRadiusM(
          baseAccuracyM: 30,
          distanceWalkedM: 0,
          elapsed: const Duration(minutes: 1));
      final stale = estimatedUncertaintyRadiusM(
          baseAccuracyM: 30,
          distanceWalkedM: 0,
          elapsed: const Duration(minutes: 30));
      expect(stale, greaterThan(fresh));
    });

    test('clamped to sane bounds', () {
      final tiny = estimatedUncertaintyRadiusM(
          baseAccuracyM: 0, distanceWalkedM: 0, elapsed: Duration.zero);
      expect(tiny, kMinEstimateRadiusM);
      final huge = estimatedUncertaintyRadiusM(
          baseAccuracyM: 100,
          distanceWalkedM: 1000000,
          elapsed: const Duration(days: 1));
      expect(huge, kMaxEstimateRadiusM);
    });

    test('monotonic in both inputs', () {
      double prev = 0;
      for (var m = 0; m <= 2000; m += 200) {
        final r = estimatedUncertaintyRadiusM(
            baseAccuracyM: 25,
            distanceWalkedM: m.toDouble(),
            elapsed: Duration(minutes: m ~/ 200));
        expect(r, greaterThanOrEqualTo(prev));
        prev = r;
      }
    });
  });

  group('connectivity state machine', () {
    ConnectivityInputs inputs({
      bool cloud = true,
      bool node = false,
      bool? browser,
      bool ok = false,
      bool err = false,
      bool never = true,
    }) =>
        ConnectivityInputs(
          cloudConfigured: cloud,
          nodeConfigured: node,
          browserOnline: browser,
          lastSyncOk: ok,
          hadSyncError: err,
          neverSynced: never,
        );

    test('clean cloud round => online', () {
      expect(inputs(ok: true, never: false).resolve(), Connectivity.online);
    });

    test('browser offline => offline even with a cloud configured', () {
      expect(inputs(browser: false).resolve(), Connectivity.offline);
    });

    test('cloud configured + error => cloud unreachable', () {
      expect(inputs(err: true, never: false, browser: true).resolve(),
          Connectivity.cloudUnreachable);
    });

    test('no backend configured => offline', () {
      expect(inputs(cloud: false, node: false).resolve(), Connectivity.offline);
    });

    test('node-only clean round => node connected', () {
      expect(
          inputs(cloud: false, node: true, ok: true, never: false).resolve(),
          Connectivity.nodeConnected);
    });

    test('node reachable while cloud offline (browser offline but node ok)',
        () {
      expect(
          inputs(cloud: true, node: true, browser: false, ok: true, never: false)
              .resolve(),
          Connectivity.online);
    });

    test('transition offline -> online flips the resolved state', () {
      final offline = inputs(browser: false);
      expect(offline.resolve(), Connectivity.offline);
      final online = inputs(browser: true, ok: true, never: false);
      expect(online.resolve(), Connectivity.online);
    });
  });
}
