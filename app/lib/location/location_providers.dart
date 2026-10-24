import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/json_store.dart';
import '../messaging/messaging_providers.dart';
import '../messaging/secure_session.dart';
import '../state/derived_state.dart';
import 'last_fix_store.dart';
import 'location_coordinator.dart';
import 'location_share.dart';
import 'location_state.dart';
import 'position_service.dart';

/// Persists the single last-good device fix in the local KeyValue table.
final lastFixStoreProvider = Provider<LastFixStore>((ref) {
  return LastFixStore(JsonStore(ref.watch(databaseProvider), 'loc:'));
});

/// Bumped whenever the cached last-good fix changes, so dependent providers
/// (map centre, default post location) reload.
final lastFixRevisionProvider = StateProvider<int>((ref) => 0);

/// The cached last-known fix, or null when none has been resolved yet.
final lastKnownFixProvider = FutureProvider<LastFix?>((ref) async {
  ref.watch(lastFixRevisionProvider);
  return ref.watch(lastFixStoreProvider).read();
});

/// Resolves the device position in the background (NOT requiring a locate tap)
/// and caches a successful read as the new last-good fix. Called on app start
/// and on resume. On failure the cached fix is left untouched (we never clear a
/// usable last-known fix just because a fresh read failed).
///
/// Returns the fresh [PositionResult] so callers can react (e.g. recentre).
///
/// Takes a [WidgetRef] because every caller is a widget (the lifecycle observer
/// and the map screen). It only reads/writes providers, never watches.
Future<PositionResult> autoResolvePosition(
  WidgetRef ref, {
  Future<PositionResult> Function()? read,
}) async {
  final PositionResult r = await (read ?? readPosition)();
  if (r.position != null) {
    final fix = LastFix(
      lat: r.position!.latitude,
      lon: r.position!.longitude,
      accuracyM: r.accuracyM,
      takenAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    await ref.read(lastFixStoreProvider).write(fix);
    ref.read(lastFixRevisionProvider.notifier).state++;
    // Drive the live "you are here" dot / default post location.
    ref.read(myPositionProvider.notifier).state = r.position;
  }
  return r;
}

/// The end-to-end location sharing coordinator for the current identity. Reuses
/// the durable Signal sessions from the messaging service (FEAT-003) to encrypt
/// the precise point per contact, and emits signed events through the shared
/// [EventStore].
final locationCoordinatorProvider =
    FutureProvider<LocationCoordinator>((ref) async {
  final id = await ref.watch(identityProvider.future);
  final kp = await authorKeyPair(id);
  final messaging = await ref.watch(messagingServiceProvider.future);
  return LocationCoordinator(
    sharer: LocationSharer(
      selfKeyPair: kp,
      clock: ref.watch(lamportClockProvider),
      factory: ref.watch(eventFactoryProvider),
    ),
    messaging: messaging,
    store: ref.watch(eventStoreProvider),
  );
});

/// The local user's own active outgoing shares (with a live countdown),
/// recomputed whenever the world state changes.
final outgoingSharesProvider =
    Provider<AsyncValue<List<OutgoingShare>>>((ref) {
  final world = ref.watch(worldStateProvider);
  final id = ref.watch(identityProvider).valueOrNull;
  if (id == null) return const AsyncValue.loading();
  return world.whenData((w) {
    final mine = w.locationShares
        .where((s) => _bytesEqual(s.author, id.keys.signingPublicKey));
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    return mine
        .map((s) => OutgoingShare(
              shareId: s.shareId,
              scope: s.scope,
              expiresMs: s.expiresMs,
              note: s.note,
              seq: s.seq,
              remaining: Duration(milliseconds: s.expiresMs - nowMs),
            ))
        .toList(growable: false)
      ..sort((a, b) => b.seq.compareTo(a.seq));
  });
});

/// Active location shares addressed to THIS device, decrypted to a usable
/// [IncomingShare] (precise point for contact shares, coarse point for public
/// beacons). Only shares the device is the audience for are ever surfaced; a
/// non-audience contact's share never reaches here (enforced by the fold's
/// [WorldState.locationSharesVisibleTo]) and its ciphertext cannot be
/// decrypted without the matching session.
final incomingSharesProvider =
    FutureProvider<List<IncomingShare>>((ref) async {
  final world = await ref.watch(worldStateProvider.future);
  final id = await ref.watch(identityProvider.future);
  final messaging = await ref.watch(messagingServiceProvider.future);

  final List<LocationShareView> visible =
      world.locationSharesVisibleTo(id.keys.signingPublicKey);
  if (visible.isEmpty) return const <IncomingShare>[];

  // Build inbound sessions keyed by the SHARER's pubkey hex so ActiveShares can
  // decrypt each contact share over our durable Signal store.
  final contactSessions = <String, SecureSession>{};
  for (final LocationShareView s in visible) {
    if (!s.scope.startsWith('contact:')) continue;
    final String sharerHex = _hex(s.author);
    if (contactSessions.containsKey(sharerHex)) continue;
    contactSessions[sharerHex] =
        await messaging.inboundSessionFrom(s.author);
  }

  final sessions = ShareSessions(
    viewerPubkey: Uint8List.fromList(id.keys.signingPublicKey),
    contactSessions: contactSessions,
  );

  // Re-fold from the log so ActiveShares (which owns decryption) resolves the
  // points over the same sessions. We fold the full log and let it apply the
  // same expiry/stop rules the WorldState fold used.
  final store = ref.watch(eventStoreProvider);
  final all = await store.dao.allEvents();
  final active = ActiveShares.fold(all);
  return active.incomingFor(sessions);
});

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _hex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
