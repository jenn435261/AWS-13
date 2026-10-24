import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mesh_app/models/event.dart';
import 'package:mesh_app/state/lock_controller.dart';
import 'package:latlong2/latlong.dart';
import 'package:mesh_app/features/shell/help_button.dart';
import 'package:mesh_app/models/resource.dart';
import 'package:mesh_app/state/identity.dart';
import 'package:mesh_app/state/settings_controller.dart';

import 'test_app.dart';

class _FailingAuth extends LocalAuthentication {
  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object?> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async => false;
}

void main() {
  test('P-lock: failed device auth keeps the app locked', () async {
    final lock = LockController(auth: _FailingAuth(), deviceLockAvailable: true)..lock();
    expect(await lock.unlock('why'), isFalse);
    expect(lock.locked, isTrue);
  });

  test('P-sig: signature is bound to the subject', () async {
    final id = await Identity.generate();
    final e = await id.sign('e1', EventType.helpRequested, 'req1');
    final moved = SignedEvent(id: e.id, type: e.type, subject: 'req2', at: e.at, author: e.author, signature: e.signature);
    expect(await id.verify(moved), isFalse);
  });

  test('P-stale: fresh is not stale; boundary at 6h', () {
    final now = DateTime(2026, 1, 1, 12);
    Resource at(Duration age) => Resource(id: 'a', kind: ResourceKind.values.first, name: '',
        location: const LatLng(0, 0), lastObserved: now.subtract(age));
    expect(at(const Duration(minutes: 5)).isStale(now: now), isFalse);
    expect(at(const Duration(hours: 7)).isStale(now: now), isTrue);
  });

  test('P-lang: saved language is restored on load', () async {
    final store = MemorySettingsStore()..values['language'] = 'vi';
    final s = SettingsController(store: store);
    await s.load();
    expect(s.language, 'vi');
  });

  testWidgets('P-sos: a 1-second press on Help does not send SOS', (tester) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    final finger = await tester.startGesture(tester.getCenter(find.byType(HelpButton)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await finger.up();
    await TestApp.settle(tester);
    expect(app.repository.requests.value.where((r) => r.sos), isEmpty);
    await TestApp.close(tester);
  });
}
