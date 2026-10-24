import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_app/data/mesh_repository.dart';
import 'package:mesh_app/data/mock_mesh_repository.dart';
import 'package:mesh_app/models/event.dart';
import 'package:mesh_app/models/help.dart';
import 'package:mesh_app/models/mission.dart';
import 'package:mesh_app/models/resource.dart';
import 'package:mesh_app/state/auth_controller.dart';
import 'package:mesh_app/state/drafts.dart';
import 'package:mesh_app/state/identity.dart';

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

  group('drafts', () {
    test('a complete draft has no problems', () {
      final draft = RequestDraft()..kind = HelpKind.water;
      expect(draft.problems(hasLocation: true), isEmpty);
    });

    test('without a location fix, the person must say where they are', () {
      final draft = RequestDraft()..kind = HelpKind.medical;
      expect(draft.problems(hasLocation: false), contains(DraftProblem.missingLocation));
      draft.locationNote = 'Basement, east stairs';
      expect(draft.problems(hasLocation: false), isEmpty);
    });

    test('people count is kept between 1 and the maximum', () {
      final draft = RequestDraft()..people = 0;
      expect(draft.people, 1);
      draft.people = 10000;
      expect(draft.people, maxPeople);
    });

    test('offering transport needs a way to transport', () {
      final draft = OfferDraft()..toggle(SupplyKind.transportation);
      expect(draft.problems, [DraftProblem.missingTransport]);
      draft.update(() => draft.transport = TransportMode.bicycle);
      expect(draft.problems, isEmpty);
      expect(draft.build().transport, TransportMode.bicycle);
    });

    test('offline category suggestions match whole word starts', () {
      expect(suggestKind('my grandmother needs insulin kept cold'), HelpKind.medicine);
      expect(suggestKind('he is bleeding badly'), HelpKind.medical);
      expect(suggestKind('necesito agua'), HelpKind.water);
      expect(suggestKind('the heat is terrible'), isNull);
      expect(suggestKind(''), isNull);
    });
  });

  group('identity', () {
    test('events are signed and any change breaks the signature', () async {
      final event = await identity.sign('e1', EventType.helpRequested, 'req1');
      expect(await identity.verify(event), isTrue);
      expect(event.wireName, 'HELP_REQUESTED');

      final tampered = SignedEvent(
        id: event.id,
        type: EventType.helpCancelled,
        subject: event.subject,
        at: event.at,
        author: event.author,
        signature: event.signature,
      );
      expect(await identity.verify(tampered), isFalse);
    });

    test('the QR code holds the ID and name, and reads back', () {
      final read = parseContactQr(identity.qrPayload('Chris'));
      expect(read?.id, identity.resilienceId);
      expect(read?.name, 'Chris');
      expect(parseContactQr('https://example.com'), isNull);
      expect(parseContactQr('resilience://contact?id=xyz&name=A'), isNull);
    });

    test('typed IDs ignore spaces and case', () {
      expect(normalizeResilienceId('8FD1 9A2C 44E1 B703'), '8fd19a2c44e1b703');
      expect(normalizeResilienceId('8fd1'), isNull);
    });
  });

  group('repository', () {
    // Random, messy drafts: the repository must accept exactly the ones the
    // phone's own checks accept, and never crash on any of them.
    test('fuzz: submit agrees with the draft checks', () async {
      final r = await repo();
      final random = Random(42);
      String junk(int maxLength) {
        final length = random.nextInt(maxLength);
        return String.fromCharCodes([
          for (var i = 0; i < length; i++) random.nextInt(0x2FFF) + 1,
        ]);
      }

      for (var i = 0; i < 500; i++) {
        final draft = RequestDraft()
          ..kind = random.nextInt(5) == 0
              ? null
              : HelpKind.values[random.nextInt(HelpKind.values.length)]
          ..urgency = Urgency.values[random.nextInt(Urgency.values.length)]
          ..people = random.nextInt(200) - 50
          ..note = junk(400)
          ..locationNote = junk(300);
        final expected = draft.problems(hasLocation: true);

        try {
          final sent = await r.submitRequest(draft, from: me);
          expect(expected, isEmpty, reason: 'accepted a bad draft');
          expect(sent.note.length, lessThanOrEqualTo(maxNoteLength));
          await r.cancelRequest(sent.id);
        } on DraftRejected catch (e) {
          expect(e.problems, expected);
        }
      }
    });

    test('a request moves through stages only after the network says so', () async {
      final r = await repo();
      final sent = await r.sendSos(from: me);
      expect(sent.stage, RequestStage.saved);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      final later = r.requests.value.firstWhere((x) => x.id == sent.id);
      expect(later.stage, RequestStage.onTheWay);
      expect(r.events.value.first.author, identity.resilienceId);
    });

    test('cancel stops the stages; restore picks up again', () async {
      final r = await repo();
      final sent = await r.sendSos(from: me);
      await r.cancelRequest(sent.id);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(r.requests.value.where((x) => x.id == sent.id), isEmpty);

      await r.restoreRequest(sent);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(r.requests.value.firstWhere((x) => x.id == sent.id).stage, RequestStage.onTheWay);
    });

    test('votes replace each other and never double count', () async {
      final r = await repo();
      Resource water() => r.resources.value.firstWhere((x) => x.id == 'w1');
      final start = water().confirmations;

      await r.vote('w1', Vote.confirm);
      await r.vote('w1', Vote.confirm);
      expect(water().confirmations, start + 1);
      await r.vote('w1', Vote.dispute);
      expect(water().confirmations, start);
      await r.vote('w1', null);
      expect((water().confirmations, water().myVote), (start, null));
    });

    test('one report stays visible as unconfirmed; old ones go stale', () async {
      final r = await repo();
      final report = r.resources.value.firstWhere((x) => x.id == 'x1');
      final generator = r.resources.value.firstWhere((x) => x.id == 'c2');
      expect(report.confidence, Confidence.unconfirmed);
      expect(generator.isStale(), isTrue);
    });

    test('directory lookups need the internet', () async {
      final r = await repo();
      await expectLater(r.findContact(username: 'riley'), throwsA(isA<NeedsInternet>()));
      r.setInternet(true);
      expect((await r.findContact(username: '@Riley'))?.name, 'Riley');
      expect(await r.findContact(phone: '+1 (408) 555-0123'), isNotNull);
      expect(await r.findContact(username: 'nobody'), isNull);
    });

    test('a mission goes from pickup to delivery, signed at each step', () async {
      final r = await repo();
      await r.acceptMission('2193', carrier: me);
      Mission mission() => r.missions.value.firstWhere((m) => m.id == '2193');
      expect((mission().stage, mission().carrierIsMe), (MissionStage.assigned, true));
      expect(r.channels.value.any((c) => c.id == 'mission-2193'), isTrue);

      await r.advanceMission('2193');
      expect(mission().stage, MissionStage.inTransit);
      await r.advanceMission('2193');
      expect(mission().stage, MissionStage.delivered);

      final types = r.events.value.where((e) => e.subject == '2193').map((e) => e.type);
      expect(types, containsAll([
        EventType.missionAccepted,
        EventType.packagePickedUp,
        EventType.deliveryCompleted,
      ]));
    });

    test('a handoff passes the package and the capability on', () async {
      final r = await repo();
      await r.acceptMission('2193', carrier: me);
      await r.advanceMission('2193');
      await r.startHandoff('2193');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final m = r.missions.value.firstWhere((m) => m.id == '2193');
      expect((m.carrier, m.carrierIsMe, m.handedOff), ('Riley', false, true));
    });

    test('wipe removes everything from this phone, then reloads public data', () async {
      final r = await repo();
      await r.sendSos(from: me);
      await r.setOffer(HelpOffer(kinds: {SupplyKind.water}, since: DateTime.now()));

      await r.wipe();

      expect(r.requests.value.where((x) => x.mine), isEmpty);
      expect(r.offer.value, isNull);
      expect(r.events.value, isEmpty);
      expect(r.nodes.value, isNotEmpty);
      expect(r.loading.value, isFalse);
    });
  });
}
