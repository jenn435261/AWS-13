import 'dart:ui' show Locale;
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/event_store.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/db/database.dart';
import 'package:resilience/db/json_store.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/l10n/strings.dart';
import 'package:resilience/l10n/strings_fr.dart';
import 'package:resilience/l10n/strings_zh.dart';
import 'package:resilience/location/position_service.dart';
import 'package:resilience/nodes/node_store.dart';
import 'package:resilience/nodes/package_store.dart';
import 'package:resilience/state/derived_state.dart';
import 'package:resilience/supplies/supply_service.dart';
import 'package:resilience/trust/root_repo.dart';
import 'package:resilience/trust/trust_roots.dart';

void main() {
  late AppDatabase db;
  late EventStore store;
  late EventFactory factory;
  late Signer signer;
  late KeyPairData owner;
  late KeyPairData stranger;
  late SupplyService svc;

  setUp(() async {
    db = AppDatabase.memory();
    signer = Signer();
    factory = EventFactory(signer: signer);
    final clock = LamportClock();
    store = EventStore(dao: db.eventDao, factory: factory, clock: clock);
    owner = await signer.generateKeyPair();
    stranger = await signer.generateKeyPair();
    svc = SupplyService(
        store: store, factory: factory, clock: clock, keyPair: owner);
  });
  tearDown(() => db.close());

  Future<WorldState> world({TrustRootStore? roots}) async {
    final w = WorldState(trustRoots: roots);
    await w.rebuild(db.eventDao);
    return w;
  }

  group('supply lifecycle', () {
    test('create with quantity, availability date and location', () async {
      final until = DateTime.now().add(const Duration(days: 2));
      final id = await svc.save(SupplyDraft(
        category: ResourceCategory.RESOURCE_CATEGORY_WATER,
        title: 'Bottled water',
        quantity: 40,
        unit: 'cases',
        availability: Availability.AVAILABILITY_CUSTOM,
        availableUntil: until,
        location: geoPointFor(const LatLng(37.33821, -121.88633)),
      ));
      final v = (await world()).resources[id]!;
      expect(v.resource.title, 'Bottled water');
      expect(v.inventory!.quantity, 40);
      expect(v.inventory!.unit, 'cases');
      expect(v.resource.availableUntilMs.toInt(), until.millisecondsSinceEpoch);
      expect(v.resource.availability, Availability.AVAILABILITY_CUSTOM);
      // Published coordinates are rounded to ~110 m.
      expect(v.resource.location.approxLat, 37.338);
      expect(v.resource.location.approxLon, -121.886);
      expect(v.resource.location.hasExact, isFalse);
      expect(latLngOf(v.resource.location), const LatLng(37.338, -121.886));
    });

    test('edit keeps the id and the latest values win', () async {
      final id = await svc.save(const SupplyDraft(
          category: ResourceCategory.RESOURCE_CATEGORY_FOOD,
          title: 'Rice',
          quantity: 5,
          unit: 'bags'));
      await svc.save(SupplyDraft(
          resourceId: id,
          category: ResourceCategory.RESOURCE_CATEGORY_FOOD,
          title: 'Rice and beans',
          quantity: 9,
          unit: 'bags'));
      final w = await world();
      expect(w.resources.length, 1);
      expect(w.resources[id]!.resource.title, 'Rice and beans');
      expect(w.resources[id]!.inventory!.quantity, 9);
    });

    test('restock, run out, take down, relist', () async {
      final id = await svc.save(const SupplyDraft(
          category: ResourceCategory.RESOURCE_CATEGORY_POWER,
          title: 'Power banks',
          quantity: 3,
          unit: 'units'));
      await svc.setQuantity(id, 12, 'units');
      expect((await world()).resources[id]!.inventory!.quantity, 12);

      await svc.markRanOut(id, 'units');
      var v = (await world()).resources[id]!;
      expect(v.inventory!.quantity, 0);
      expect(v.availableQuantity, 0);
      expect(v.resource.amount, AmountBand.AMOUNT_BAND_LOW);

      await svc.takeDown(id);
      expect((await world()).resources[id]!.withdrawn, isTrue);

      await svc.relist((await world()).resources[id]!.resource);
      expect((await world()).resources[id]!.withdrawn, isFalse);
    });

    test('a stranger cannot edit, restock or withdraw someone else\'s supply',
        () async {
      final id = await svc.save(const SupplyDraft(
          category: ResourceCategory.RESOURCE_CATEGORY_MEDICINE,
          title: 'Insulin',
          quantity: 10,
          unit: 'vials'));
      final evil = SupplyService(
          store: store,
          factory: factory,
          clock: LamportClock(),
          keyPair: stranger);
      await evil.takeDown(id);
      await evil.setQuantity(id, 0, 'vials');
      await evil.save(SupplyDraft(
          resourceId: id,
          category: ResourceCategory.RESOURCE_CATEGORY_OTHER,
          title: 'HACKED'));
      final v = (await world()).resources[id]!;
      expect(v.withdrawn, isFalse);
      expect(v.inventory!.quantity, 10);
      expect(v.resource.title, 'Insulin');
      expect(v.owner, owner.publicKey);
    });
  });

  group('providers', () {
    Future<SignedEvent> alert(KeyPairData by) => factory.buildFromMessage(
          keyPair: by,
          clock: LamportClock(),
          type: EventType.EVENT_TYPE_EMERGENCY_ALERT,
          body: EmergencyAlertBody(alertId: 'a1', title: 'Boil water'),
        );

    test('an alert from a community member is ignored', () async {
      await store.apply(await alert(stranger));
      expect((await world()).emergencyAlerts, isEmpty);
    });

    test('an alert from a trusted root shows', () async {
      await store.apply(await alert(owner));
      final w = await world(roots: TrustRootStore(seed: [owner.publicKey]));
      expect(w.emergencyAlerts.single.body.title, 'Boil water');
      expect(w.provenanceOf(owner.publicKey),
          ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG);
      expect(w.provenanceOf(stranger.publicKey),
          ProvenanceKind.PROVENANCE_KIND_COMMUNITY);
    });

    test('a root can certify someone, who then becomes verified', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final cert = await factory.buildFromMessage(
        keyPair: owner,
        clock: LamportClock(),
        type: EventType.EVENT_TYPE_ORG_CERTIFICATE,
        body: OrgCertificateBody(
          orgRootPubkey: owner.publicKey,
          subjectPubkey: stranger.publicKey,
          orgName: 'Red Cross',
          provenance: ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG,
          validFromMs: Int64(now),
          validUntilMs: Int64(now + 100000),
        ),
      );
      await store.apply(cert);
      await store.apply(await alert(stranger));
      final roots = TrustRootStore(seed: [owner.publicKey]);
      final w = await world(roots: roots);
      expect(w.provenanceOf(stranger.publicKey),
          ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG);
      expect(w.emergencyAlerts.length, 1);

      // Untrusting the root removes the badge again.
      roots.remove(owner.publicKey);
      final w2 = await world(roots: roots);
      expect(w2.provenanceOf(stranger.publicKey),
          ProvenanceKind.PROVENANCE_KIND_COMMUNITY);
      expect(w2.emergencyAlerts, isEmpty);
    });

    test('trusted roots persist through the repo', () async {
      final repo = TrustRootRepo(JsonStore(db, 'root:'));
      await repo.add(owner.publicKey, 'Red Cross');
      final list = await repo.list();
      expect(list.single.name, 'Red Cross');
      expect(list.single.bytes, owner.publicKey);
      await repo.remove(owner.publicKey);
      expect(await repo.list(), isEmpty);
    });
  });

  group('saved nodes', () {
    test('parse the node QR JSON and bare addresses', () {
      expect(
          parseNodeAddress('{"v":1,"name":"Shelter 18","url":"http://192.168.1.20:8090"}')!
              .name,
          'Shelter 18');
      expect(parseNodeAddress('192.168.1.20:8090/')!.url,
          'http://192.168.1.20:8090');
      expect(parseNodeAddress('https://node.example.org/x?y=1')!.url,
          'https://node.example.org');
      expect(parseNodeAddress('not a url at all'), isNull);
      expect(parseNodeAddress('ftp://host'), isNull);
      expect(parseNodeAddress('{"url":'), isNull);
      expect(parseNodeAddress(''), isNull);
    });

    test('add, dedupe, rename, activate, remove', () async {
      final s = NodeStore(JsonStore(db, 'node:'), JsonStore(db, 'nodecfg:'));
      final a = await s.add('http://10.0.0.5:8090', name: 'Gym');
      final again = await s.add('http://10.0.0.5:8090');
      expect(again.id, a.id);
      final b = await s.add('http://10.0.0.6:8090');
      expect(b.name, '10.0.0.6', reason: 'defaults to the host');
      expect((await s.list()).length, 2);

      await s.rename(b.id, 'Library');
      expect((await s.list()).last.name, 'Library');
      await s.rename(b.id, '   ');
      expect((await s.list()).last.name, 'Library', reason: 'blank ignored');

      await s.setActive(a.id);
      expect(await s.activeId(), a.id);
      await s.remove(a.id);
      expect(await s.activeId(), isNull, reason: 'removing active clears it');
      expect((await s.list()).single.name, 'Library');
    });
  });

  group('package library', () {
    test('keeps several versions of one package and edits them', () async {
      final s = PackageStore(JsonStore(db, 'pkg:'));
      final v1 = await s.add(
          kind: PackageKind.map,
          name: 'Bay Area map',
          version: '1',
          url: 'http://n/node/v1/map/bay.pmtiles');
      await s.add(
          kind: PackageKind.map,
          name: 'Bay Area map',
          version: '2',
          url: 'http://n/node/v1/map/bay2.pmtiles');
      var all = await s.list();
      expect(all.length, 2);
      expect(all.map((p) => p.version).toSet(), {'1', '2'});

      await s.update(v1.copyWith(version: '1.1', notes: 'patched'));
      all = await s.list();
      expect(all.firstWhere((p) => p.id == v1.id).version, '1.1');

      await s.remove(v1.id);
      expect((await s.list()).single.version, '2');
    });
  });

  group('languages', () {
    test('French and Mandarin cover every English key', () {
      final en = <String>{};
      // Probe through the public lookup: any key English knows must resolve to
      // something other than the key itself in fr and zh.
      for (final k in kStringsFr.keys) {
        en.add(k);
      }
      const l = L10n(Locale('en'));
      for (final k in en) {
        // Two English words are spelled exactly like their key.
        if (k == 'confirmations' || k == 'disputes') continue;
        expect(l.t(k), isNot(k), reason: 'English is missing $k');
      }
      for (final k in kStringsZh.keys) {
        expect(kStringsFr.containsKey(k), isTrue, reason: 'fr missing $k');
      }
      for (final k in kStringsFr.keys) {
        expect(kStringsZh.containsKey(k), isTrue, reason: 'zh missing $k');
      }
      expect(L10n.supportedLocales.map((e) => e.languageCode),
          containsAll(['en', 'es', 'fr', 'zh']));
      expect(const L10n(Locale('zh')).t('nav_map'), '地图');
      expect(const L10n(Locale('fr')).t('nav_map'), 'Carte');
    });
  });
}
