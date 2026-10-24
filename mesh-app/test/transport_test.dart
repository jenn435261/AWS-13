import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mesh_app/data/demo_area.dart';
import 'package:mesh_app/data/mock_mesh_repository.dart';
import 'package:mesh_app/data/transport/location_policy.dart';
import 'package:mesh_app/data/transport/lora_transport.dart';
import 'package:mesh_app/data/transport/outbox.dart';
import 'package:mesh_app/data/transport/router.dart';
import 'package:mesh_app/data/transport/simulated_transport.dart';
import 'package:mesh_app/data/wire/event_codec.dart';
import 'package:mesh_app/main.dart';
import 'package:mesh_app/models/envelope.dart';
import 'package:mesh_app/models/help.dart';
import 'package:mesh_app/models/network.dart';
import 'package:mesh_app/services/location_service.dart';
import 'package:mesh_app/state/identity.dart';

/// A denied or missing GPS reading, then whatever the test pushes next.
class ScriptedLocation implements LocationProvider {
  final _fixes = StreamController<LocationFix?>.broadcast();
  int listeners = 0;

  void add(LocationFix? fix) => _fixes.add(fix);

  @override
  Stream<LocationFix?> watch() {
    listeners++;
    return _fixes.stream;
  }

  Future<void> close() => _fixes.close();
}

/// The five links, wired the way the phone wires them.
class _Links {
  _Links({
    this.latency = const Duration(milliseconds: 2),
    bool nearbyCarriesPrivate = false,
  }) {
    bool publicOnly(Envelope e) => !e.needsEndToEnd;
    cloud = SimulatedTransport(LinkKind.cloud, latency: latency, accepts: publicOnly);
    node = SimulatedTransport(LinkKind.node, latency: latency, accepts: publicOnly);
    lora = SimulatedTransport(
      LinkKind.lora,
      latency: latency,
      accepts: LoraTransport.carries,
    );
    wifi = SimulatedTransport(
      LinkKind.wifi,
      latency: latency,
      accepts: nearbyCarriesPrivate ? null : publicOnly,
    );
    bluetooth = SimulatedTransport(
      LinkKind.bluetooth,
      latency: latency,
      accepts: nearbyCarriesPrivate ? null : publicOnly,
    );
    router = TransportRouter([cloud, node, lora, wifi, bluetooth]);
    sharing = ValueNotifier(false);
    outbox = Outbox(
      router: router,
      policy: LocationPolicy(sharing),
      // Zero so a retry does not depend on the wall clock under fake time.
      retryDelay: Duration.zero,
      sendTimeout: const Duration(seconds: 2),
    );
  }

  late final SimulatedTransport cloud;
  late final SimulatedTransport node;
  late final SimulatedTransport lora;
  late final SimulatedTransport wifi;
  late final SimulatedTransport bluetooth;
  late final TransportRouter router;
  late final ValueNotifier<bool> sharing;
  late final Outbox outbox;
  final Duration latency;

  List<SimulatedTransport> get all => [cloud, node, lora, wifi, bluetooth];

  void up(SimulatedTransport link, {int peers = 1, bool reachesCloud = false}) {
    link.set(up: true, peers: peers, reachesCloud: reachesCloud);
  }

  void dispose() {
    outbox.dispose();
    router.dispose();
    sharing.dispose();
  }

  /// Waits until [ready], long enough for several retries.
  Future<void> until(bool Function() ready) async {
    var done = ready();
    for (var i = 0; i < 40 && !done; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      done = ready();
    }
    expect(
      done,
      isTrue,
      reason: 'still waiting: ${outbox.waiting.map((e) => e.id).join(", ")}',
    );
  }
}

Envelope _env(
  EnvelopeKind kind, {
  required String id,
  String? subject,
  Map<String, Object?> fields = const {},
  LatLng? at,
}) =>
    Envelope(
      id: id,
      kind: kind,
      subject: subject ?? id,
      author: 'phone',
      createdAt: DateTime.utc(2026, 10, 24),
      fields: fields,
      location: at,
    );

void main() {
  late Identity identity;
  setUpAll(() async => identity = await Identity.generate());

  group('outbox', () {
    test('nothing is lost or sent twice, and urgent items go first', () async {
      final links = _Links();
      addTearDown(links.dispose);
      final seen = <String>[];
      final sub = links.outbox.delivered.listen((d) => seen.add(d.envelope.id));
      addTearDown(sub.cancel);

      // Queued low first, then urgent, then a cancel about the same request.
      final vote = _env(EnvelopeKind.vote, id: 'vote', subject: 'other');
      final sos = _env(EnvelopeKind.sos, id: 'sos', subject: 'sos');
      final first = _env(EnvelopeKind.helpRequest, id: 'first', subject: 'same');
      final cancel = _env(EnvelopeKind.helpCancelled, id: 'cancel', subject: 'same');
      for (final e in [vote, sos, first, cancel]) {
        expect(links.outbox.add(e), isTrue);
        expect(links.outbox.add(e), isFalse);
      }

      links.up(links.cloud, reachesCloud: true);
      await links.until(() => links.outbox.waiting.isEmpty);

      expect(links.cloud.arrivals.map((e) => e.id), ['sos', 'first', 'cancel', 'vote']);
      expect(seen, ['sos', 'first', 'cancel', 'vote']);
      expect(links.cloud.stored, {'sos', 'first', 'cancel', 'vote'});
    });

    test('an item taken back before it leaves is not sent', () async {
      final links = _Links();
      addTearDown(links.dispose);
      final held = _env(EnvelopeKind.helpRequest, id: 'held');
      expect(links.outbox.add(held), isTrue);
      expect(links.outbox.withdraw('held'), isTrue);
      links.up(links.cloud, reachesCloud: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(links.cloud.stored, isEmpty);
      expect(links.outbox.add(held), isTrue);
      await links.until(() => links.outbox.waiting.isEmpty);
      expect(links.cloud.stored, {'held'});
    });

    test('a dropped ack is sent again and the far side keeps one copy', () async {
      final links = _Links();
      addTearDown(links.dispose);
      final seen = <String>[];
      final sub = links.outbox.delivered.listen((d) => seen.add(d.envelope.id));
      addTearDown(sub.cancel);

      links.outbox.add(_env(EnvelopeKind.sos, id: 'sos'));
      links.cloud.dropNext = SimulatedDrop.beforeAck;
      links.up(links.cloud, reachesCloud: true);
      await links.until(() => seen.length == 1);

      expect(links.cloud.sends, greaterThan(1));
      expect(links.cloud.arrivals.where((e) => e.id == 'sos').length, greaterThan(1));
      expect(links.cloud.stored, {'sos'});
      expect(seen, ['sos']);
      expect(links.outbox.waiting, isEmpty);
    });

    test('a cut before arrival is not stored, then goes once', () async {
      final links = _Links();
      addTearDown(links.dispose);
      links.outbox.add(_env(EnvelopeKind.helpRequest, id: 'req'));
      links.cloud.dropNext = SimulatedDrop.beforeArrival;
      links.up(links.cloud, reachesCloud: true);
      await links.until(() => links.outbox.waiting.isEmpty);

      expect(links.cloud.arrivals.map((e) => e.id), ['req']);
      expect(links.cloud.stored, {'req'});
    });

    test('an SOS waits behind an earlier item about the same subject', () async {
      final links = _Links();
      addTearDown(links.dispose);
      final seen = <String>[];
      final sub = links.outbox.delivered.listen((d) => seen.add(d.envelope.id));
      addTearDown(sub.cancel);

      links.outbox.add(_env(EnvelopeKind.vote, id: 'vote', subject: 'same'));
      links.outbox.add(_env(EnvelopeKind.sos, id: 'sos', subject: 'same'));
      links.up(links.lora);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(links.lora.stored, isEmpty);
      expect(links.outbox.waiting.map((e) => e.id), ['vote', 'sos']);

      links.up(links.wifi);
      await links.until(() => links.outbox.waiting.isEmpty);
      expect(seen, ['vote', 'sos']);
      expect(links.wifi.stored, {'vote'});
      expect(links.lora.stored, {'sos'});
    });

    test('random up and down links lose nothing and confirm each item once', () async {
      final links = _Links(latency: const Duration(milliseconds: 1));
      addTearDown(links.dispose);
      final seen = <String>[];
      final sub = links.outbox.delivered.listen((d) {
        expect(seen, isNot(contains(d.envelope.id)));
        seen.add(d.envelope.id);
      });
      addTearDown(sub.cancel);

      final items = [
        for (var i = 0; i < 8; i++)
          _env(EnvelopeKind.helpRequest, id: 'r$i', subject: 's$i'),
        _env(
          EnvelopeKind.message,
          id: 'direct',
          subject: 'dm',
          fields: const {'channelType': 'direct', 'text': 'secret'},
        ),
      ];
      for (final e in items) {
        links.outbox.add(e);
      }

      final rng = Random(20261024);
      for (var step = 0; step < 24; step++) {
        for (final link in links.all) {
          if (rng.nextDouble() < 0.45) {
            final on = rng.nextBool();
            link.set(up: on, peers: rng.nextInt(3), reachesCloud: on && rng.nextBool());
            if (on && rng.nextDouble() < 0.3) {
              link.dropNext = rng.nextBool()
                  ? SimulatedDrop.beforeAck
                  : SimulatedDrop.beforeArrival;
            }
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 4));
      }
      for (final link in links.all) {
        link.dropNext = null;
        links.up(link, peers: 2, reachesCloud: true);
      }
      final wanted = {for (final e in items) e.id}..remove('direct');
      await links.until(
        () => wanted.every(seen.contains) && !links.outbox.waiting.any((e) => wanted.contains(e.id)),
      );

      expect(seen.toSet(), wanted);
      expect(seen.length, wanted.length);
      expect(links.outbox.isWaiting('direct'), isTrue);
      for (final link in [links.cloud, links.node, links.lora]) {
        expect(link.stored, isNot(contains('direct')));
      }
      final arrived = {for (final link in links.all) ...link.stored};
      expect(arrived.containsAll(wanted), isTrue);
    });

    test('a live position still waiting is dropped when sharing stops', () async {
      final links = _Links(nearbyCarriesPrivate: true);
      addTearDown(links.dispose);
      links.sharing.value = true;
      final live = _env(
        EnvelopeKind.liveLocation,
        id: 'live',
        subject: '2193',
        at: const LatLng(37.33, -121.88),
      );
      expect(links.outbox.add(live), isTrue);
      links.sharing.value = false;
      links.up(links.wifi);
      await links.until(() => !links.outbox.isWaiting('live'));
      expect(links.wifi.stored, isEmpty);
      expect(links.outbox.add(live), isFalse);
    });
  });

  group('router', () {
    test('urgent traffic uses LoRa before nearby phones; other traffic does not', () {
      final links = _Links();
      addTearDown(links.dispose);
      for (final link in links.all) {
        links.up(link, reachesCloud: true);
      }
      final sos = _env(EnvelopeKind.sos, id: 'sos');
      final vote = _env(EnvelopeKind.vote, id: 'vote');

      expect(links.router.routesFor(sos).map((t) => t.kind), [
        LinkKind.cloud,
        LinkKind.node,
        LinkKind.lora,
        LinkKind.wifi,
        LinkKind.bluetooth,
      ]);
      expect(links.router.routesFor(vote).map((t) => t.kind), [
        LinkKind.cloud,
        LinkKind.node,
        LinkKind.wifi,
        LinkKind.bluetooth,
      ]);

      links.cloud.set(up: false);
      links.node.set(up: false);
      expect(links.router.routesFor(sos).first.kind, LinkKind.lora);
      expect(
        links.router.routesFor(sos, skip: {links.lora}).first.kind,
        LinkKind.wifi,
      );

      final down = links.router.status(
        queued: 2,
        lastSync: DateTime.utc(2026, 10, 24),
        lastGlobalSync: DateTime.utc(2026, 10, 24),
      );
      expect(down.queued, 2);
      expect(down.internet, isFalse);
      expect(down.hasRoute, isTrue);
      expect(down.lora, isTrue);
    });

    test('with every link down there is no route', () {
      final links = _Links();
      addTearDown(links.dispose);
      final status = links.router.status(
        queued: 0,
        lastSync: DateTime.utc(2026, 10, 24),
        lastGlobalSync: DateTime.utc(2026, 10, 24),
      );
      expect(status.hasRoute, isFalse);
      expect(status.internet, isFalse);
      expect(status.gatewayOnline, isFalse);
      expect(links.router.routesFor(_env(EnvelopeKind.sos, id: 'sos')), isEmpty);
    });
  });

  group('location policy', () {
    test('only a chosen place, a resource, or a live delivery may carry coordinates', () {
      final sharing = ValueNotifier(false);
      addTearDown(sharing.dispose);
      final policy = LocationPolicy(sharing);
      const at = LatLng(37.33, -121.88);

      Envelope sample(EnvelopeKind kind, {Map<String, Object?> fields = const {}, LatLng? location}) =>
          _env(kind, id: kind.name, fields: fields, at: location);

      expect(policy.admit(sample(EnvelopeKind.sos, location: at))!.location, at);
      expect(policy.admit(sample(EnvelopeKind.resourceCreated, location: at))!.location, at);
      expect(policy.admit(sample(EnvelopeKind.message, location: at))!.location, isNull);
      expect(policy.admit(sample(EnvelopeKind.liveLocation, location: at)), isNull);

      sharing.value = true;
      expect(policy.admit(sample(EnvelopeKind.liveLocation, location: at))!.location, at);
      sharing.value = false;
      expect(policy.maySend(sample(EnvelopeKind.liveLocation, location: at)), isFalse);

      final cleaned = policy.admit(
        sample(EnvelopeKind.message, fields: const {'lat': 1, 'note': 'hi'}),
      )!;
      expect(cleaned.fields.containsKey('lat'), isFalse);
      expect(cleaned.fields['note'], 'hi');
    });

    test('a typed location stands until a GPS fix is accurate to 20 meters', () {
      const manual = LocationFix(
        LatLng(37.33, -121.88),
        50,
        source: LocationSource.manual,
        label: 'door',
      );
      const poor = LocationFix(
        LatLng(37.34, -121.89),
        accurateGpsMeters + 0.1,
        source: LocationSource.device,
      );
      const accurate = LocationFix(
        LatLng(37.3352, -121.8811),
        accurateGpsMeters,
        source: LocationSource.device,
      );

      expect(chooseLocation(manual: null, device: null).shown, isNull);
      expect(chooseLocation(manual: manual, device: null).shown!.source, LocationSource.manual);
      expect(chooseLocation(manual: manual, device: poor).manual, manual);
      final replaced = chooseLocation(manual: manual, device: accurate);
      expect(replaced.shown, accurate);
      expect(replaced.manual, isNull);
    });
  });

  group('codecs', () {
    test('the same envelope is the same signed event, and it decodes', () async {
      final codec = EventCodec(identity);
      final request = Envelope(
        id: 'e1',
        kind: EnvelopeKind.helpRequest,
        subject: 'req1',
        author: identity.resilienceId,
        createdAt: DateTime.utc(2026, 10, 24, 12),
        fields: const {
          'ref': 'ref1',
          'kind': 'water',
          'urgency': 'soon',
          'note': 'jugs',
          'locationNote': 'gym',
        },
        location: const LatLng(37.3352, -121.8811),
      );
      final first = await codec.encode(request);
      final again = await codec.encode(request);
      expect(again.idHex, first.idHex);
      expect(again.lamport, first.lamport);
      expect(await first.verify(), isTrue);

      final back = EventCodec.decode(first)!;
      expect(back.kind, EnvelopeKind.helpRequest);
      expect(back.fields['note'], 'jugs');
      expect(back.fields['kind'], 'water');
      expect(back.fields['locationNote'], 'gym');
      expect(back.location!.latitude, closeTo(37.3352, 1e-9));
      expect(back.location!.longitude, closeTo(-121.8811, 1e-9));

      final sos = await codec.encode(
        _env(EnvelopeKind.sos, id: 'sos', at: const LatLng(37.34, -121.88)),
      );
      expect(EventCodec.decode(sos)!.kind, EnvelopeKind.sos);
      expect(sos.type, WireType.helpRequested);

      final cancelled = await codec.encode(_env(EnvelopeKind.helpCancelled, id: 'c'));
      expect(cancelled.type, WireType.helpCancelled);

      final message = await codec.encode(
        _env(
          EnvelopeKind.message,
          id: 'm',
          subject: 'water',
          fields: const {'channelId': 'water', 'channelType': 'public', 'text': 'hello'},
        ),
      );
      final text = EventCodec.decode(message)!;
      expect(text.fields['text'], 'hello');
      expect(text.subject, 'water');

      final flipped = WireEvent(
        type: first.type,
        author: Uint8List.fromList(first.author),
        lamport: first.lamport,
        prev: Uint8List.fromList(first.prev),
        createdAtMs: first.createdAtMs,
        body: Uint8List.fromList(first.body),
        eventId: Uint8List.fromList(first.eventId),
        signature: Uint8List.fromList(first.signature)..[0] ^= 0xff,
      );
      expect(await flipped.verify(), isFalse);
      expect(await first.verify(), isTrue);

      expect(codec.canEncode(_env(EnvelopeKind.liveLocation, id: 'live')), isFalse);
      await expectLater(
        codec.encode(_env(EnvelopeKind.liveLocation, id: 'live', at: const LatLng(1, 2))),
        throwsArgumentError,
      );
    });
  });

  group('GPS fallback', () {
    test('REAL_GPS false uses the demo point', () async {
      expect(realGps, isFalse);
      final repo = MockMeshRepository(
        identity: identity,
        simulateTraffic: false,
        loadDelay: Duration.zero,
        locationProvider: realGps ? DeviceLocationProvider() : null,
      );
      addTearDown(repo.dispose);
      await Future<void>.delayed(Duration.zero);
      final fix = repo.location.value!;
      expect(fix.source, LocationSource.demo);
      expect(fix.point.latitude, closeTo(demoCenter.latitude, 0.01));
      expect(fix.point.longitude, closeTo(demoCenter.longitude, 0.01));
    });

    test('a denied GPS fix can fall back to a typed location', () async {
      final gps = ScriptedLocation();
      addTearDown(gps.close);
      final repo = MockMeshRepository(
        identity: identity,
        simulateTraffic: false,
        loadDelay: Duration.zero,
        locationProvider: gps,
      );
      addTearDown(repo.dispose);
      for (var i = 0; i < 5 && gps.listeners == 0; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(gps.listeners, 1);

      gps.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(repo.location.value, isNull);

      await repo.setManualLocation(const LatLng(37.33, -121.88), label: ' Library, 2nd floor ');
      expect(repo.location.value!.source, LocationSource.manual);
      expect(repo.location.value!.label, 'Library, 2nd floor');

      gps.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(repo.location.value!.source, LocationSource.manual);
      expect(repo.location.value!.label, 'Library, 2nd floor');
    });
  });
}
