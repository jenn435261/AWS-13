import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/logistics/location_view.dart';

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
}
