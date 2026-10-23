import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_assist.dart';
import '../ai/bedrock_ai_client.dart';
import '../ai/local_rules_ai.dart';
import '../core/event_factory.dart';
import '../core/event_store.dart';
import '../core/lamport_clock.dart';
import '../core/signing.dart';
import '../db/database.dart';
import '../identity/identity_store.dart';
import '../state/derived_state.dart';
import '../trust/trust_roots.dart';

/// Hand-written Riverpod providers wiring the engines (Waves 1-3) to the UI.
/// No codegen — plain providers so builds stay fast.

/// The app's cloud API base URL. Empty => fully offline (AI falls back to
/// local rules; sync uses local transports only). Overridden at deploy time.
final cloudBaseUrlProvider = Provider<String>((ref) => '');

/// The local Drift database. Overridden in tests with AppDatabase.memory().
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

/// The shared Ed25519 signer.
final signerProvider = Provider<Signer>((ref) => Signer());

/// The shared Lamport clock for locally-created events.
final lamportClockProvider = Provider<LamportClock>((ref) => LamportClock());

/// The secret store for identity keys (OS keystore on device).
final secretStoreProvider = Provider<SecretStore>((ref) {
  return FlutterSecureSecretStore();
});

/// The device identity (generated on first run, stable thereafter).
final identityProvider = FutureProvider<DeviceIdentity>((ref) async {
  final store = IdentityStore(ref.watch(secretStoreProvider));
  return store.getOrCreateIdentity(defaultDisplayName: 'Resilience User');
});

/// The event store (verify-on-apply, dedup, sync digests).
final eventStoreProvider = Provider<EventStore>((ref) {
  final db = ref.watch(databaseProvider);
  return EventStore(
    dao: db.eventDao,
    factory: EventFactory(signer: ref.watch(signerProvider)),
    clock: ref.watch(lamportClockProvider),
  );
});

/// The event factory for building new signed events.
final eventFactoryProvider = Provider<EventFactory>((ref) {
  return EventFactory(signer: ref.watch(signerProvider));
});

/// The trusted org roots (seeded out-of-band / from a readiness package).
/// Empty for now; WorldState folds the cert graph + revocations from the log.
final trustRootsProvider = Provider<TrustRootStore>((ref) => TrustRootStore());

/// A monotonically-increasing tick bumped whenever new events are applied, so
/// derived-state providers recompute. Call [bumpWorld] after writing events.
final worldRevisionProvider = StateProvider<int>((ref) => 0);

void bumpWorld(WidgetRef ref) {
  ref.read(worldRevisionProvider.notifier).state++;
}

void bumpWorldRef(Ref ref) {
  ref.read(worldRevisionProvider.notifier).state++;
}

/// The folded world state (resources, requests, offers, shelters, alerts),
/// rebuilt whenever [worldRevisionProvider] changes.
final worldStateProvider = FutureProvider<WorldState>((ref) async {
  ref.watch(worldRevisionProvider); // recompute trigger
  final store = ref.watch(eventStoreProvider);
  final world = WorldState(trustRoots: ref.watch(trustRootsProvider));
  await world.rebuild(store.dao);
  return world;
});

/// Convenience selectors derived from the world state.
final rankedResourcesProvider = Provider<AsyncValue<List<ResourceView>>>((ref) {
  return ref.watch(worldStateProvider).whenData((w) => w.rankedResources());
});

final helpRequestsProvider = Provider<AsyncValue<List<HelpRequestView>>>((ref) {
  return ref.watch(worldStateProvider).whenData((w) => w.helpRequests);
});

final emergencyAlertsProvider =
    Provider<AsyncValue<List<EmergencyAlertView>>>((ref) {
  return ref.watch(worldStateProvider).whenData((w) => w.emergencyAlerts);
});

/// The AI assistant: Bedrock-backed when a cloud URL is configured, otherwise
/// the deterministic local rules engine. Always falls back gracefully.
final aiAssistProvider = Provider<AiAssist>((ref) {
  final base = ref.watch(cloudBaseUrlProvider);
  final local = LocalRulesAiClient();
  if (base.isEmpty) return local;
  return BedrockAiClient(baseUrl: base, fallback: local);
});

/// Builds a KeyPairData usable by the EventFactory from the device identity.
Future<KeyPairData> authorKeyPair(DeviceIdentity id) {
  return Signer().keyPairFromSeed(id.keys.signingPrivateKey);
}

/// Whether the UI should show the Deliveries tab. Conditional per spec §64:
/// shown when the user offers transport OR holds a distributor capability OR
/// has an active mission. For now wired to a flag that logistics state sets;
/// defaults to false so the tab stays hidden until relevant.
final showDeliveriesProvider = StateProvider<bool>((ref) => false);

/// The current app locale (for the language switcher). Null = system default.
final localeProvider = StateProvider<Locale?>((ref) => null);
