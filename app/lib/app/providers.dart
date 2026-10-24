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
import '../db/json_store.dart';
import '../gen/resilience/v1/event.pb.dart' show ProvenanceKind;
import '../nodes/node_store.dart';
import '../nodes/package_store.dart';
import '../supplies/supply_service.dart';
import '../trust/root_repo.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../identity/contact_store.dart';
import '../identity/identity_card.dart';
import '../identity/identity_store.dart';
import '../state/derived_state.dart';
import '../trust/trust_roots.dart';

/// Hand-written Riverpod providers wiring the engines (Waves 1-3) to the UI.
/// No codegen — plain providers so builds stay fast.

/// Default cloud API for native builds. Override per build with
/// `--dart-define=CLOUD_BASE_URL=...` (empty string => fully offline). On web
/// the bundle is served by the API itself, so main() overrides this with the
/// page's own origin.
const kDefaultCloudBaseUrl = String.fromEnvironment('CLOUD_BASE_URL',
    defaultValue: 'https://resilience.chrisccluk.live');

/// Shared client key for the cloud's CLIENT_API_KEYS gate. Never committed:
/// native builds pass `--dart-define=CLOUD_API_KEY=...`; web reads it from the
/// server's /app-config.json at startup.
const kDefaultCloudApiKey = String.fromEnvironment('CLOUD_API_KEY');

/// The app's cloud API base URL. Empty => fully offline (AI falls back to
/// local rules; sync uses local transports only).
final cloudBaseUrlProvider = Provider<String>((ref) => kDefaultCloudBaseUrl);

/// The X-Api-Key sent to the cloud. Empty => no header.
final cloudApiKeyProvider = Provider<String>((ref) => kDefaultCloudApiKey);

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
  await ref.watch(trustRootsLoadedProvider.future);
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
  return BedrockAiClient(
    baseUrl: base,
    apiKey: ref.watch(cloudApiKeyProvider),
    fallback: local,
  );
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


/// Saved contacts (public identity cards), persisted in the local database.
final contactStoreProvider =
    Provider<ContactStore>((ref) => ContactStore(ref.watch(databaseProvider)));

/// Bumped after the contact list changes so [contactsProvider] reloads.
final contactsRevisionProvider = StateProvider<int>((ref) => 0);

final contactsProvider = FutureProvider<List<IdentityCard>>((ref) async {
  ref.watch(contactsRevisionProvider);
  return ref.watch(contactStoreProvider).list();
});


// --- Trusted roots (persisted local trust decisions) -------------------------

final trustRootRepoProvider = Provider<TrustRootRepo>(
    (ref) => TrustRootRepo(JsonStore(ref.watch(databaseProvider), 'root:')));

/// Loads persisted roots into [trustRootsProvider]'s store before the world
/// state is folded, so verified-org badges survive a restart.
final trustRootsLoadedProvider = FutureProvider<void>((ref) async {
  final store = ref.watch(trustRootsProvider);
  for (final r in await ref.watch(trustRootRepoProvider).list()) {
    store.add(r.bytes);
  }
});

/// Bumped after trusting/untrusting a root so lists and badges recompute.
final trustRevisionProvider = StateProvider<int>((ref) => 0);

final trustedRootsListProvider = FutureProvider<List<TrustedRoot>>((ref) async {
  ref.watch(trustRevisionProvider);
  return ref.watch(trustRootRepoProvider).list();
});

/// Whether the device identity is a verified organization member (a trusted
/// root, or certified by a chain from one).
final isVerifiedProviderProvider = Provider<bool>((ref) {
  final me = ref.watch(identityProvider).valueOrNull;
  final world = ref.watch(worldStateProvider).valueOrNull;
  if (me == null || world == null) return false;
  return world.provenanceOf(me.keys.signingPublicKey) ==
      ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG;
});

// --- Supplies ----------------------------------------------------------------

final supplyServiceProvider = FutureProvider<SupplyService>((ref) async {
  final id = await ref.watch(identityProvider.future);
  final kp = await authorKeyPair(id);
  return SupplyService(
    store: ref.watch(eventStoreProvider),
    factory: ref.watch(eventFactoryProvider),
    clock: ref.watch(lamportClockProvider),
    keyPair: kp,
    provenance: ref.read(isVerifiedProviderProvider)
        ? ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG
        : ProvenanceKind.PROVENANCE_KIND_COMMUNITY,
  );
});

// --- Nodes & offline packages -------------------------------------------------

final nodeStoreProvider = Provider<NodeStore>((ref) {
  final db = ref.watch(databaseProvider);
  return NodeStore(JsonStore(db, 'node:'), JsonStore(db, 'nodecfg:'));
});

final nodesRevisionProvider = StateProvider<int>((ref) => 0);

final nodesProvider = FutureProvider<List<SavedNode>>((ref) async {
  ref.watch(nodesRevisionProvider);
  return ref.watch(nodeStoreProvider).list();
});

final activeNodeIdProvider = FutureProvider<String?>((ref) async {
  ref.watch(nodesRevisionProvider);
  return ref.watch(nodeStoreProvider).activeId();
});

final packageStoreProvider = Provider<PackageStore>((ref) =>
    PackageStore(JsonStore(ref.watch(databaseProvider), 'pkg:')));

final packagesRevisionProvider = StateProvider<int>((ref) => 0);

final packagesProvider = FutureProvider<List<SavedPackage>>((ref) async {
  ref.watch(packagesRevisionProvider);
  return ref.watch(packageStoreProvider).list();
});

// --- Position (one-shot, user initiated) ---------------------------------------

/// The last position the user chose to read, or null. Never polled.
final myPositionProvider = StateProvider<LatLng?>((ref) => null);
