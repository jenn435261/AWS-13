import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:mesh_app/data/map_tiles.dart';
import 'package:mesh_app/data/mesh_repository.dart';
import 'package:mesh_app/data/mock_mesh_repository.dart';
import 'package:mesh_app/models/event.dart';
import 'package:mesh_app/models/help.dart';
import 'package:mesh_app/models/mesh_message.dart';
import 'package:mesh_app/models/network.dart';
import 'package:mesh_app/models/resource.dart';
import 'package:mesh_app/state/auth_controller.dart';
import 'package:mesh_app/state/identity.dart';

/// Rules the mutation pass showed were untested: each test here fails if the
/// rule it names is broken.
void main() {
  const me = AuthController.guest;
  late Identity identity;
  setUpAll(() async => identity = await Identity.generate());

  Future<MockMeshRepository> repo() async {
    final r = MockMeshRepository(
      identity: identity,
      simulateTraffic: false,
      loadDelay: Duration.zero,
      stageDelay: const Duration(milliseconds: 1),
    );
    addTearDown(r.dispose);
    await Future<void>.delayed(Duration.zero);
    return r;
  }

  NetworkStatus network({bool lora = false, bool gateway = false}) => NetworkStatus(
        internet: false,
        peers: 0,
        node: false,
        lora: lora,
        gatewayOnline: gateway,
        lastSync: DateTime.now(),
        lastGlobalSync: DateTime.now(),
      );

  Future<void> wait() => Future<void>.delayed(const Duration(milliseconds: 40));

  group('routes', () {
    test('with no route at all, a message and an SOS wait on the phone', () async {
      final r = await repo();
      r.debugSetNetwork(network());
      await r.sendMessage('neighborhood', 'hello', from: me);
      final sos = await r.sendSos(from: me);
      await wait();
      expect(r.messages.value.last.status, DeliveryStatus.queued);
      expect(r.requests.value.firstWhere((x) => x.id == sos.id).stage, RequestStage.saved);
    });

    test('with no gateway, a request reaches the mesh but is never "verified"', () async {
      final r = await repo();
      r.debugSetNetwork(network(lora: true));
      final sos = await r.sendSos(from: me);
      await wait();
      expect(r.requests.value.firstWhere((x) => x.id == sos.id).stage, RequestStage.mesh);
    });

    test('clearing the cache keeps messages that are still being sent', () async {
      final r = await repo();
      r.debugSetNetwork(network());
      await r.sendMessage('neighborhood', 'still going', from: me);
      await r.clearCache();
      expect(r.messages.value.map((m) => m.text), contains('still going'));
    });
  });

  group('requests', () {
    test("a request someone else took can't be accepted", () async {
      final r = await repo();
      final sos = await r.sendSos(from: me);
      await wait();
      expect(r.requests.value.firstWhere((x) => x.id == sos.id).helperName, 'Jordan');
      await r.acceptRequest(sos.id, helper: me);
      final after = r.requests.value.firstWhere((x) => x.id == sos.id);
      expect((after.helperName, after.helpingIsMe), ('Jordan', false));
    });

    test('cancel then restore reaches "helper found" only once', () async {
      final r = await repo();
      var helperFound = 0;
      final sub = r.notices.listen((n) {
        if (n is HelperFoundNotice) helperFound++;
      });
      addTearDown(sub.cancel);
      final sos = await r.sendSos(from: me);
      await r.cancelRequest(sos.id);
      await r.restoreRequest(sos);
      await wait();
      expect(helperFound, 1);
    });
  });

  group('wipe', () {
    test('wipe deletes sent messages and stops a handoff in progress', () async {
      final r = await repo();
      await r.sendMessage('neighborhood', 'private', from: me);
      await r.acceptMission('2193', carrier: me);
      await r.advanceMission('2193');
      await r.startHandoff('2193');
      await r.wipe();
      await wait();
      expect(r.messages.value.map((m) => m.text), isNot(contains('private')));
      expect(r.events.value.map((e) => e.type), isNot(contains(EventType.packageTransferred)));
    });
  });

  group('trust', () {
    Resource resource({int confirmations = 0, int disputes = 0}) => Resource(
          id: 'x',
          kind: ResourceKind.values.first,
          name: '',
          location: const LatLng(0, 0),
          lastObserved: DateTime.now(),
          confirmations: confirmations,
          disputes: disputes,
        );

    test('disputes lower confidence; many confirmations raise it', () {
      expect(resource(confirmations: 3).confidence, Confidence.medium);
      expect(resource(confirmations: 3, disputes: 1).confidence, Confidence.low);
      expect(resource(confirmations: 10).confidence, Confidence.high);
      expect(resource().confidence, Confidence.unconfirmed);
    });
  });

  group('street map', () {
    test('after a failed tile, the map retries on its own', () async {
      var calls = 0;
      final tiles = MapTiles(
        key: 'k1',
        retryAfter: const Duration(milliseconds: 10),
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode({'session': 's$calls'}), 200);
        }),
      );
      addTearDown(tiles.dispose);
      await tiles.open(dark: false, languageCode: 'en');
      tiles.tileFailed();
      await wait();
      expect((tiles.status, calls), (MapTilesStatus.ready, 2));
    });

    test('a late answer for the old look is ignored', () async {
      final first = Completer<http.Response>();
      var calls = 0;
      final tiles = MapTiles(
        key: 'k1',
        client: MockClient((_) {
          calls++;
          return calls == 1
              ? first.future
              : Future.value(http.Response(jsonEncode({'session': 'dark'}), 200));
        }),
      );
      addTearDown(tiles.dispose);
      final light = tiles.open(dark: false, languageCode: 'en');
      await tiles.open(dark: true, languageCode: 'en');
      first.complete(http.Response(jsonEncode({'session': 'light'}), 200));
      await light;
      expect(tiles.urlTemplate, contains('session=dark'));
    });
  });
}
