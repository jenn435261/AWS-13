import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../ai/ai_assist.dart';
import '../ai/bedrock_ai_client.dart';
import '../ai/local_rules_ai.dart';
import '../auth/authenticator.dart';
import '../core/haptics/haptics.dart';
import 'settings_store.dart';
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
import '../logistics/capabilities.dart';
import '../logistics/mission.dart';
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

/// Trusted root (lowercase hex Ed25519 public key) a node's signed package
/// manifest must be signed by before the app trusts its checksums. Set per
/// build with `--dart-define=PACKAGES_TRUSTED_ROOT=...`. Empty => the app
/// cannot verify a signed manifest, so it shows an honest "unverified" state
/// and never claims a download is checksum-verified.
const kDefaultPackagesTrustedRoot =
    String.fromEnvironment('PACKAGES_TRUSTED_ROOT');

/// The trusted root key for signed package manifests (see
/// [kDefaultPackagesTrustedRoot]).
final packagesTrustedRootProvider =
    Provider<String>((ref) => kDefaultPackagesTrustedRoot);

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

// --- Settings (local, device-only preferences + optional identity) -----------

/// Persists user settings in the local KeyValue table.
final settingsStoreProvider = Provider<SettingsStore>((ref) =>
    SettingsStore(JsonStore(ref.watch(databaseProvider), 'settings:')));

/// Bumped after settings change so [settingsProvider] reloads.
final settingsRevisionProvider = StateProvider<int>((ref) => 0);

/// The current [AppSettings]. While loading, callers see the safe defaults
/// (haptics ON, unlock-requirement OFF, anonymous), so the UI never blocks.
final settingsProvider = FutureProvider<AppSettings>((ref) async {
  ref.watch(settingsRevisionProvider);
  return ref.watch(settingsStoreProvider).load();
});

/// Synchronous view of settings for call sites (haptics) that fire during a
/// gesture. Falls back to defaults until the async load completes.
final settingsValueProvider = Provider<AppSettings>((ref) {
  return ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
});

/// Writes [next] and triggers a reload.
Future<void> updateSettings(WidgetRef ref, AppSettings next) async {
  await ref.read(settingsStoreProvider).save(next);
  ref.read(settingsRevisionProvider.notifier).state++;
}

/// The haptics helper (platform-appropriate backend). Stateless; gating is done
/// per-call against the Settings "Haptic feedback" toggle.
final hapticsProvider = Provider<Haptics>((ref) => const Haptics());

/// Fires a haptic gated by the current setting. Safe to call from any widget.
void fireHaptic(WidgetRef ref, HapticKind kind) {
  final enabled = ref.read(settingsValueProvider).hapticsEnabled;
  ref.read(hapticsProvider).fire(kind, enabled: enabled);
}

/// The device unlock authenticator (local_auth on native, honest "unavailable"
/// on web). Overridden with a FakeAuthenticator in tests.
final authenticatorProvider =
    Provider<Authenticator>((ref) => defaultAuthenticator());


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

/// The active saved node (the one the user chose), or null.
final activeNodeProvider = FutureProvider<SavedNode?>((ref) async {
  final id = await ref.watch(activeNodeIdProvider.future);
  if (id == null) return null;
  final nodes = await ref.watch(nodesProvider.future);
  for (final n in nodes) {
    if (n.id == id) return n;
  }
  return null;
});

/// The full URL of an offline PMTiles map served by the active node, or null
/// when there is no active node or the node serves no map.
///
/// The region is discovered honestly from the node's own catalog
/// (`GET /node/v1/map` list via `/node/v1/packages`), so the app never guesses
/// file names. The first `map` item is used. Any failure => null (the map view
/// then keeps the online OSM raster layer).
final nodePmtilesUrlProvider = FutureProvider<String?>((ref) async {
  final node = await ref.watch(activeNodeProvider.future);
  if (node == null) return null;
  final base = node.url.replaceAll(RegExp(r'/$'), '');
  try {
    final resp = await http
        .get(Uri.parse('$base/node/v1/packages'))
        .timeout(const Duration(seconds: 6));
    if (resp.statusCode != 200) return null;
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) return null;
    final items = decoded['items'];
    if (items is! List) return null;
    for (final it in items) {
      if (it is Map && it['kind'] == 'map') {
        final path = it['path'];
        if (path is String && path.isNotEmpty) {
          return path.startsWith('http') ? path : '$base$path';
        }
      }
    }
    return null;
  } catch (_) {
    return null;
  }
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

// --- Missions (provider assignment + carrier acceptance) ----------------------

/// All missions visible to this device, folded from the local log.
///
/// Mission creation and assignment are provider actions: the [MissionStore]
/// gate ignores a `MISSION_CREATED`/`MISSION_MATCHED` signed by a key that is
/// not a verified organization (`WorldState.provenanceOf == VERIFIED_ORG`), so
/// a non-provider can never create or assign a mission (abuse rule). Carriers
/// still accept via `MISSION_ACCEPTED`, which carries its own author signature.
final missionsProvider = FutureProvider<List<MissionView>>((ref) async {
  ref.watch(worldRevisionProvider);
  final me = await ref.watch(identityProvider.future);
  final world = await ref.watch(worldStateProvider.future);
  final store = ref.watch(eventStoreProvider);
  final events = await store.dao.allEvents();
  final missions = MissionStore(factory: ref.watch(eventFactoryProvider));
  return missions.missionsForViewer(
    viewerPubkey: me.keys.signingPublicKey,
    capabilities: CapabilitySet(const <String, Capability>{}),
    events: events,
    isVerifiedProvider: (author) =>
        world.provenanceOf(author) ==
        ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG,
  );
});
