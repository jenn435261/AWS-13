import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/app/providers.dart';
import 'package:resilience/app/settings_store.dart';
import 'package:resilience/auth/authenticator.dart';
import 'package:resilience/db/database.dart';
import 'package:resilience/l10n/strings.dart';
import 'package:resilience/ui/components/reveal_gate.dart';

/// NOTE: real biometric behaviour (local_auth) needs a real device and cannot
/// run headlessly — see docs/DECISIONS.md (Round 2 / FEAT-003). These tests
/// drive the gate through a FakeAuthenticator instead.

const _secret = 'SECRET-ID-VALUE';

Widget _harness({
  required FakeAuthenticator auth,
  required bool requireUnlock,
}) {
  final db = AppDatabase.memory();
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWith((ref) {
        ref.onDispose(db.close);
        return db;
      }),
      authenticatorProvider.overrideWithValue(auth),
      // Provide settings synchronously so the gate reads the right toggle
      // immediately (no async FutureProvider resolution to wait on).
      settingsValueProvider
          .overrideWithValue(AppSettings(requireUnlock: requireUnlock)),
    ],
    child: MaterialApp(
      localizationsDelegates: const [L10n.delegate],
      supportedLocales: L10n.supportedLocales,
      home: Scaffold(
        body: RevealGate(
          revealLabel: 'Reveal ID',
          builder: (ctx, hide) => Column(
            children: [
              const Text(_secret),
              TextButton(onPressed: hide, child: const Text('Hide')),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Authenticator fake', () {
    test('approves when available and set to approve', () async {
      final a = FakeAuthenticator(approve: true);
      expect(await a.isBiometricAvailable(), isTrue);
      expect(await a.authenticate(reason: 'x'), AuthOutcome.approved);
      expect(a.authenticateCalls, 1);
    });

    test('denies when set to deny', () async {
      final a = FakeAuthenticator(approve: false);
      expect(await a.authenticate(reason: 'x'), AuthOutcome.denied);
    });

    test('reports unavailable when no biometric', () async {
      final a = FakeAuthenticator(available: false);
      expect(await a.isBiometricAvailable(), isFalse);
      expect(await a.authenticate(reason: 'x'), AuthOutcome.unavailable);
    });
  });

  group('RevealGate', () {
    testWidgets('hidden by default — secret not shown', (tester) async {
      await tester.pumpWidget(
          _harness(auth: FakeAuthenticator(), requireUnlock: false));
      await tester.pump();
      expect(find.text(_secret), findsNothing);
      expect(find.text('Reveal ID'), findsOneWidget);
    });

    testWidgets('reveals directly when unlock is NOT required',
        (tester) async {
      final auth = FakeAuthenticator();
      await tester.pumpWidget(_harness(auth: auth, requireUnlock: false));
      await tester.pump();
      await tester.tap(find.text('Reveal ID'));
      await tester.pump();
      expect(find.text(_secret), findsOneWidget);
      // No unlock prompt when not required.
      expect(auth.authenticateCalls, 0);
    });

    testWidgets('reveals after an approving authenticator', (tester) async {
      final auth = FakeAuthenticator(approve: true);
      await tester.pumpWidget(_harness(auth: auth, requireUnlock: true));
      await tester.pump();
      await tester.tap(find.text('Reveal ID'));
      await tester.pumpAndSettle();
      expect(find.text(_secret), findsOneWidget);
      expect(auth.authenticateCalls, 1);
    });

    testWidgets('stays hidden when the authenticator denies', (tester) async {
      final auth = FakeAuthenticator(approve: false);
      await tester.pumpWidget(_harness(auth: auth, requireUnlock: true));
      await tester.pump();
      await tester.tap(find.text('Reveal ID'));
      await tester.pumpAndSettle();
      expect(find.text(_secret), findsNothing);
    });

    testWidgets('web/unsupported fallback shows confirm + warning',
        (tester) async {
      final auth = FakeAuthenticator(available: false);
      await tester.pumpWidget(_harness(auth: auth, requireUnlock: true));
      await tester.pump();
      await tester.tap(find.text('Reveal ID'));
      // Avoid pumpAndSettle: the busy spinner animates while the dialog is open.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // The honest no-biometric warning dialog is shown.
      expect(
          find.text(const L10n(Locale('en')).t('no_biometric_warning')),
          findsOneWidget);
      // Confirming reveals the secret.
      await tester.tap(find.text(const L10n(Locale('en')).t('reveal_anyway')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(_secret), findsOneWidget);
    });

    testWidgets('auto-hides after the 30s timeout', (tester) async {
      final auth = FakeAuthenticator();
      await tester.pumpWidget(_harness(auth: auth, requireUnlock: false));
      await tester.pump();
      await tester.tap(find.text('Reveal ID'));
      await tester.pump();
      expect(find.text(_secret), findsOneWidget);

      // Advance past the auto-hide timeout.
      await tester.pump(kRevealTimeout + const Duration(seconds: 1));
      await tester.pump();
      expect(find.text(_secret), findsNothing);
      expect(find.text('Reveal ID'), findsOneWidget);
    });

    testWidgets('manual Hide re-locks immediately', (tester) async {
      final auth = FakeAuthenticator();
      await tester.pumpWidget(_harness(auth: auth, requireUnlock: false));
      await tester.pump();
      await tester.tap(find.text('Reveal ID'));
      await tester.pump();
      expect(find.text(_secret), findsOneWidget);
      await tester.tap(find.text('Hide'));
      await tester.pump();
      expect(find.text(_secret), findsNothing);
    });
  });
}
