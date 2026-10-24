import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/app/settings_store.dart';
import 'package:resilience/db/database.dart';
import 'package:resilience/db/json_store.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/identity/identity_card.dart';
import 'package:resilience/identity/identity_keys.dart';
import 'package:resilience/state/derived_state.dart';
import 'package:resilience/trust/trust_roots.dart';

void main() {
  group('AppSettings defaults (privacy by default)', () {
    test('haptics ON, require-unlock OFF, anonymous QR by default', () {
      const s = AppSettings();
      expect(s.hapticsEnabled, isTrue);
      expect(s.requireUnlock, isFalse);
      expect(s.includeNameInQr, isFalse);
      expect(s.displayName, isEmpty);
      expect(s.orgRole, isEmpty);
    });
  });

  group('SettingsStore round-trip', () {
    late AppDatabase db;
    late SettingsStore store;

    setUp(() {
      db = AppDatabase.memory();
      store = SettingsStore(JsonStore(db, 'settings:'));
    });
    tearDown(() => db.close());

    test('empty store returns safe defaults', () async {
      final s = await store.load();
      expect(s.hapticsEnabled, isTrue);
      expect(s.requireUnlock, isFalse);
      expect(s.includeNameInQr, isFalse);
    });

    test('saves and reloads every field', () async {
      await store.save(const AppSettings(
        hapticsEnabled: false,
        requireUnlock: true,
        displayName: 'Rosa',
        orgRole: 'Red Cross volunteer',
        contactNote: 'call me',
        includeNameInQr: true,
      ));
      final s = await store.load();
      expect(s.hapticsEnabled, isFalse);
      expect(s.requireUnlock, isTrue);
      expect(s.displayName, 'Rosa');
      expect(s.orgRole, 'Red Cross volunteer');
      expect(s.contactNote, 'call me');
      expect(s.includeNameInQr, isTrue);
    });
  });

  group('Identity QR name inclusion', () {
    /// Mirrors the contacts screen rule: embed a name ONLY when the user both
    /// set one AND toggled include-name. Otherwise the card is anonymous.
    IdentityCard buildQrCard(IdentityKeys keys, AppSettings s) {
      final includeName =
          s.includeNameInQr && s.displayName.trim().isNotEmpty;
      return IdentityCard.fromIdentityKeys(
        keys,
        displayName: includeName ? s.displayName.trim() : '',
      );
    }

    test('omits the name by default (anonymous)', () async {
      final keys = await IdentityKeys.generate();
      const s = AppSettings(displayName: 'Rosa'); // include toggle OFF
      final card = buildQrCard(keys, s);
      expect(card.displayName, isEmpty);

      // The decoded QR payload must also carry no name.
      final decoded = IdentityCard.fromQrPayload(card.toQrPayload());
      expect(decoded.displayName, isEmpty);
      expect(decoded.resilienceId, keys.resilienceId);
    });

    test('includes the name only when the toggle is ON and a name is set',
        () async {
      final keys = await IdentityKeys.generate();
      const s = AppSettings(displayName: 'Rosa', includeNameInQr: true);
      final card = buildQrCard(keys, s);
      expect(card.displayName, 'Rosa');
      final decoded = IdentityCard.fromQrPayload(card.toQrPayload());
      expect(decoded.displayName, 'Rosa');
    });

    test('toggle ON with no name stays anonymous', () async {
      final keys = await IdentityKeys.generate();
      const s = AppSettings(includeNameInQr: true); // displayName empty
      final card = buildQrCard(keys, s);
      expect(card.displayName, isEmpty);
    });
  });

  group('Self-asserted org/role never grants a verified badge (abuse)', () {
    test('an identity profile org/role does not change provenance', () async {
      final keys = await IdentityKeys.generate();
      // A user fills in a convincing org/role in Settings > Identity.
      const s = AppSettings(
        displayName: 'Chief',
        orgRole: 'FEMA Regional Director',
        includeNameInQr: true,
      );
      // These fields live only in local settings; they never enter the signed
      // event log, so the trust fold (certificate chains only) must still see
      // this author as COMMUNITY, never VERIFIED_ORG.
      final world = WorldState(trustRoots: TrustRootStore());
      world.rebuildFromEvents(const []);
      expect(
        world.provenanceOf(keys.signingPublicKey),
        ProvenanceKind.PROVENANCE_KIND_COMMUNITY,
      );
      // The QR card made from the profile carries the (self-chosen) name but
      // nothing in it can confer verification.
      final card = IdentityCard.fromIdentityKeys(keys,
          displayName: s.includeNameInQr ? s.displayName : '');
      expect(card.hasConsistentResilienceId, isTrue);
    });
  });
}
