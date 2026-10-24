import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_app/data/demo_area.dart';
import 'package:mesh_app/features/map/map_pins.dart';
import 'package:mesh_app/features/map/map_screen.dart';
import 'package:mesh_app/features/map/nearby.dart';
import 'package:mesh_app/features/map/set_location_screen.dart';
import 'package:mesh_app/features/more/network_screen.dart';
import 'package:mesh_app/features/requests/request_screen.dart';
import 'package:mesh_app/l10n/labels.dart';
import 'package:mesh_app/models/help.dart';
import 'package:mesh_app/models/resource.dart';
import 'package:mesh_app/state/settings_controller.dart';

import 'map_test_app.dart';
import 'test_app.dart';

final _en = MapTestApp.strings();

HelpRequest _request(
  String id, {
  Urgency urgency = Urgency.soon,
  double north = 0,
  bool mine = false,
  bool sos = false,
  RequestStage stage = RequestStage.verified,
  bool helpingIsMe = false,
}) =>
    HelpRequest(
      id: id,
      kind: HelpKind.water,
      urgency: urgency,
      people: 1,
      createdAt: DateTime.now(),
      senderName: 'Someone',
      location: offsetMeters(demoCenter, north, 0),
      mine: mine,
      sos: sos,
      stage: stage,
      helpingIsMe: helpingIsMe,
    );

Resource _resource(String id, double north, {bool stale = false}) => Resource(
      id: id,
      kind: ResourceKind.water,
      name: id,
      location: offsetMeters(demoCenter, north, 0),
      lastObserved: stale ? DateTime.now().subtract(const Duration(days: 30)) : DateTime.now(),
    );

/// Every piece of text on screen that had to be cut short.
List<String> _cutOff(WidgetTester tester) => [
      for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText)))
        if (p.didExceedMaxLines) p.text.toPlainText(),
    ];

void main() {
  group('neighbor first', () {
    test('other people\'s open requests lead, most urgent then nearest; then resources', () {
      final items = nearbyItems(
        requests: [
          _request('later-near', urgency: Urgency.later, north: 50),
          _request('soon-far', north: 900),
          _request('soon-near', north: 100),
          _request('now-far', urgency: Urgency.now, north: 1500),
          _request('sos', urgency: Urgency.later, sos: true, north: 2000),
          _request('mine', urgency: Urgency.now, north: 10, mine: true),
          _request('taken', stage: RequestStage.assigned, north: 20),
          _request('helping', stage: RequestStage.assigned, helpingIsMe: true, north: 30),
          _request('helped', stage: RequestStage.resolved, helpingIsMe: true, north: 30),
        ],
        resources: [
          _resource('water-far', 400),
          _resource('water-near', 5),
          _resource('water-stale', 150, stale: true),
        ],
        from: demoCenter,
      );
      expect([for (final i in items) i.id], [
        'sos', 'now-far', 'soon-near', 'soon-far', 'later-near', // open requests
        'helping', // ones this phone already took on
        'water-near', 'water-far', 'water-stale', // places; stale ones rank lower
      ]);
    });

    test('the layer switches still filter the row', () {
      final items = nearbyItems(
        requests: [_request('r')],
        resources: [_resource('w', 10)],
        from: demoCenter,
        showRequests: false,
      );
      expect([for (final i in items) i.id], ['w']);
    });

    testWidgets('the first card on the map is the most urgent request nearby', (tester) async {
      final app = await MapTestApp.create(tester);
      await app.pump(tester);
      final first = app.repository.requests.value
          .where((r) => !r.mine && r.isOpen)
          .reduce((a, b) => a.urgency.index <= b.urgency.index ? a : b);
      expect(first.urgency, Urgency.now);
      final card = find.descendant(of: find.byType(PageView), matching: find.text(_en.requestTitle(first)));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: find.byType(PageView), matching: find.text(_en.urgency(Urgency.now))),
        findsOneWidget,
      );
      await TestApp.close(tester);
    });
  });

  group('no GPS', () {
    testWidgets('a Set my location chip shows, and cards claim no distances', (tester) async {
      final app = await MapTestApp.create(tester, gps: false);
      await app.pump(tester);
      expect(find.text(_en.mapSetLocation), findsOneWidget);
      expect(find.textContaining(' m away'), findsNothing);
      expect(find.byType(MeDot), findsNothing);
      await TestApp.close(tester);
    });

    testWidgets('My location asks where you are instead of jumping to the demo point', (tester) async {
      final app = await MapTestApp.create(tester, gps: false);
      await app.pump(tester);
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
      final before = map.camera.center;

      await tester.tap(find.byTooltip(_en.mapSetLocation));
      await TestApp.settle(tester);
      expect(find.byType(SetLocationScreen), findsOneWidget);
      expect(find.text(_en.mapSetLocationTitle), findsOneWidget);

      // Back changes nothing.
      await tester.pageBack();
      await TestApp.settle(tester);
      expect(find.byType(SetLocationScreen), findsNothing);
      expect(app.noGps.fix.value, isNull);
      expect(map.camera.center, before);
      await TestApp.close(tester);
    });

    testWidgets('drag the map to where you are, add a note, confirm', (tester) async {
      final app = await MapTestApp.create(tester, gps: false);
      await app.pump(tester);
      await tester.tap(find.text(_en.mapSetLocation));
      await TestApp.settle(tester);

      final picker = find.descendant(of: find.byType(SetLocationScreen), matching: find.byType(FlutterMap));
      final start = tester.widget<FlutterMap>(picker).mapController!.camera.center;
      await tester.drag(picker, const Offset(-150, 0));
      await TestApp.settle(tester);
      await tester.enterText(find.byType(TextField), '  Library, 2nd floor ');
      await tester.tap(find.text(_en.mapUseLocation));
      await TestApp.settle(tester);

      final (point, label) = app.noGps.setByHand.single;
      expect(label, 'Library, 2nd floor');
      // Dragging the map left moves the pin east.
      expect(point.longitude, greaterThan(start.longitude));
      expect(point.latitude, closeTo(start.latitude, 1e-4));
      expect(find.byType(SetLocationScreen), findsNothing);
      expect(find.text(_en.mapLocationSaved), findsOneWidget);

      // Shown as set by hand, not as GPS: a still dot, and words saying so.
      expect(find.text(_en.mapSetByYouNamed('Library, 2nd floor')), findsOneWidget);
      expect(tester.widget<MeDot>(find.byType(MeDot)).live, isFalse);
      expect(find.bySemanticsLabel('${_en.mapYouAreHere}, ${_en.mapSetByYou}'), findsOneWidget);
      expect(find.textContaining(' m away'), findsWidgets);
      await TestApp.close(tester);
    });

    testWidgets('with GPS the dot is live, and holding My location still sets it by hand',
        (tester) async {
      final app = await MapTestApp.create(tester);
      await app.pump(tester);
      expect(find.text(_en.mapSetLocation), findsNothing);
      expect(tester.widget<MeDot>(find.byType(MeDot)).live, isTrue);

      await tester.longPress(find.byTooltip(_en.myLocation));
      await TestApp.settle(tester);
      expect(find.byType(SetLocationScreen), findsOneWidget);
      await TestApp.close(tester);
    });
  });

  group('adding', () {
    testWidgets('Add here opens the add sheet at the center of the map', (tester) async {
      final app = await MapTestApp.create(tester);
      await app.pump(tester);
      final center = tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera.center;

      await tester.tap(find.text(_en.mapAddHere));
      await TestApp.settle(tester);
      expect(find.text(_en.addHereTitle), findsOneWidget);
      await tester.tap(find.text(_en.resourceKind(addableResourceKinds.first)));
      await TestApp.settle(tester);

      final added = app.repository.resources.value.where((r) => r.mine).single;
      expect(added.kind, addableResourceKinds.first);
      expect(added.location, center);
      await TestApp.close(tester);
    });

    testWidgets('holding the map still adds where you hold', (tester) async {
      final app = await MapTestApp.create(tester);
      await app.pump(tester);
      await tester.longPressAt(const Offset(80, 300));
      await TestApp.settle(tester);
      expect(find.text(_en.addHereTitle), findsOneWidget);
      await TestApp.close(tester);
    });

    testWidgets('the "nothing nearby" card is not a dead button: it opens the add flow',
        (tester) async {
      final app = await MapTestApp.create(tester);
      await app.pump(tester);
      await tester.tap(find.byTooltip(_en.layers));
      await TestApp.settle(tester);
      for (final layer in [_en.layerFacilities, _en.layerLive, _en.layerRequests]) {
        await tester.tap(find.text(layer));
        await tester.pump();
      }
      await tester.tapAt(const Offset(195, 40));
      await TestApp.settle(tester);

      final empty = find.text(_en.nothingNearby);
      expect(empty, findsOneWidget);
      final semantics = tester.ensureSemantics();
      expect(tester.getSemantics(empty).getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      semantics.dispose();
      await tester.tap(empty);
      await TestApp.settle(tester);
      expect(find.text(_en.addHereTitle), findsOneWidget);
      await TestApp.close(tester);
    });
  });

  group('Back returns to the map', () {
    testWidgets('from a request opened from its card', (tester) async {
      final app = await MapTestApp.create(tester);
      await app.pump(tester);
      final first = app.repository.requests.value.firstWhere((r) => !r.mine && r.urgency == Urgency.now);
      await tester.tap(find.descendant(of: find.byType(PageView), matching: find.text(_en.requestTitle(first))));
      await TestApp.settle(tester);
      expect(find.byType(RequestScreen), findsOneWidget);

      await tester.pageBack();
      await TestApp.settle(tester);
      expect(MapTestApp.router(tester).state.uri.path, '/map');
      expect(find.byType(MapScreen).hitTestable(), findsOneWidget);
      await TestApp.close(tester);
    });

    testWidgets('from the network status', (tester) async {
      final app = await MapTestApp.create(tester);
      await app.pump(tester);
      await tester.tap(find.text('${_en.statusOffline}  ·  ${_en.statusReady}'));
      await TestApp.settle(tester);
      expect(find.byType(NetworkScreen), findsOneWidget);

      await tester.pageBack();
      await TestApp.settle(tester);
      expect(MapTestApp.router(tester).state.uri.path, '/map');
      expect(find.byType(MapScreen).hitTestable(), findsOneWidget);
      await TestApp.close(tester);
    });
  });

  group('large text', () {
    testWidgets('at 150% in Vietnamese nothing on the map is cut off', (tester) async {
      final app = await MapTestApp.create(tester, language: 'vi', textScale: 1.5);
      await app.pump(tester);
      final vi = MapTestApp.strings('vi');
      // The status pill wraps instead of ending in "Sẵn s…".
      expect(find.text('${vi.statusOffline}  ·  ${vi.statusReady}'), findsOneWidget);
      expect(_cutOff(tester), isEmpty);
      expect(tester.takeException(), isNull);

      await TestApp.close(tester);
    });

    for (final language in supportedLanguages.keys) {
      testWidgets('nothing is cut off at 100, 125 and 150% in $language', (tester) async {
        for (final scale in textScales) {
          final app = await MapTestApp.create(tester, language: language, textScale: scale, gps: false);
          await app.pump(tester, size: const Size(360, 740));
          expect(_cutOff(tester), isEmpty, reason: 'map at ${scale * 100}%');
          expect(tester.takeException(), isNull);

          await tester.tap(find.text(MapTestApp.strings(language).mapSetLocation));
          await TestApp.settle(tester);
          expect(_cutOff(tester), isEmpty, reason: 'set location at ${scale * 100}%');
          expect(tester.takeException(), isNull);
          await TestApp.close(tester);
        }
      });

      testWidgets('no text under 16px on the new map screens in $language', (tester) async {
        final app = await MapTestApp.create(tester, language: language, gps: false);
        await app.pump(tester, size: const Size(360, 740));
        expectNoSmallText(tester, 'map without GPS ($language)');

        await tester.tap(find.byTooltip(MapTestApp.strings(language).layers));
        await TestApp.settle(tester);
        expectNoSmallText(tester, 'map layers ($language)');
        await tester.tapAt(const Offset(180, 40));
        await TestApp.settle(tester);

        await tester.tap(find.text(MapTestApp.strings(language).mapSetLocation));
        await TestApp.settle(tester);
        expectNoSmallText(tester, 'set location ($language)');
        await TestApp.close(tester);
      });
    }
  });
}
