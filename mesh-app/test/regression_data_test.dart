import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_app/data/mock_mesh_repository.dart';
import 'package:mesh_app/models/event.dart';
import 'package:mesh_app/models/help.dart';
import 'package:mesh_app/models/resource.dart';
import 'package:mesh_app/models/social.dart';
import 'package:mesh_app/state/auth_controller.dart';
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

  test('contact remove + undo (as contacts_screen does) keeps source/kind/verified', () async {
    final r = await repo();
    final duc = r.contacts.value.firstWhere((c) => c.name == 'Duc');
    final city = r.contacts.value.firstWhere((c) => c.name == 'City of San Jose');
    expect(duc.metInPerson, isFalse);
    for (final c in [duc, city]) {
      await r.removeContact(c.id);
      await r.restoreContact(c); // the revert used by the UI
    }
    final duc2 = r.contacts.value.firstWhere((c) => c.id == duc.id);
    final city2 = r.contacts.value.firstWhere((c) => c.id == city.id);
    expect(duc2.metInPerson, isFalse, reason: 'username contact became "met in person"');
    expect(city2.kind, ContactKind.organization);
    expect(city2.verifiedOrganization, isTrue);
  });

  test('vote confirm + undo restores freshness', () async {
    final r = await repo();
    final c2 = r.resources.value.firstWhere((x) => x.id == 'c2');
    expect(c2.isStale(), isTrue);
    await r.vote('c2', Vote.confirm);
    await r.restoreVote(c2); // undo
    final after = r.resources.value.firstWhere((x) => x.id == 'c2');
    expect(after.confirmations, c2.confirmations);
    expect(after.isStale(), isTrue, reason: 'undone confirm left resource looking fresh');
  });

  test('contact undo puts it back in its old place', () async {
    final r = await repo();
    final before = r.contacts.value.map((c) => c.id).toList();
    final duc = r.contacts.value.firstWhere((c) => c.name == 'Duc');
    await r.removeContact(duc.id);
    await r.restoreContact(duc);
    expect(r.contacts.value.map((c) => c.id).toList(), before);
  });

  test('accept + undo returns request to its original stage', () async {
    final r = await repo();
    final r3 = r.requests.value.firstWhere((x) => x.id == 'r3');
    expect(r3.stage, RequestStage.mesh);
    await r.acceptRequest('r3', helper: me);
    await r.releaseRequest('r3');
    final after = r.requests.value.firstWhere((x) => x.id == 'r3');
    expect(after.stage, RequestStage.mesh, reason: 'stage jumped to ${after.stage}');
  });

  test('verify accepts an event whose author was changed', () async {
    final e = await identity.sign('e1', EventType.helpRequested, 'r1');
    final forged = SignedEvent(
      id: e.id, type: e.type, subject: e.subject, at: e.at,
      author: 'ffffffffffffffff', signature: e.signature);
    expect(await identity.verify(forged), isFalse);
  });

  test('verify throws instead of returning false on malformed signature', () async {
    final e = await identity.sign('e1', EventType.helpRequested, 'r1');
    final bad = SignedEvent(
      id: e.id, type: e.type, subject: e.subject, at: e.at,
      author: e.author, signature: e.signature.substring(1));
    expect(await identity.verify(bad), isFalse);
  });
}
