import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/json_store.dart';
import '../location/location_providers.dart';
import 'cloud_sync.dart';

/// Live sync state surfaced to the UI (Network Status screen). Every field is
/// something the sync client actually measured, so the UI never claims a
/// capability that is not wired.
class SyncStatus {
  /// Wall-clock millis of the last SUCCESSFUL sync, or null if we have not had
  /// a clean round yet.
  final int? lastSyncedMs;

  /// Our own events not yet confirmed uploaded (max of cloud/node pending).
  final int pendingCount;

  /// The last error message (truthful, short), or null if the last round was
  /// clean. Kept even after lastSyncedMs is set so a later failure is visible.
  final String? lastError;

  /// Whether a sync round is in flight (so the UI can show a spinner).
  final bool syncing;

  const SyncStatus({
    this.lastSyncedMs,
    this.pendingCount = 0,
    this.lastError,
    this.syncing = false,
  });

  SyncStatus copyWith({
    int? lastSyncedMs,
    int? pendingCount,
    Object? lastError = _sentinel,
    bool? syncing,
  }) =>
      SyncStatus(
        lastSyncedMs: lastSyncedMs ?? this.lastSyncedMs,
        pendingCount: pendingCount ?? this.pendingCount,
        lastError:
            identical(lastError, _sentinel) ? this.lastError : lastError as String?,
        syncing: syncing ?? this.syncing,
      );

  static const Object _sentinel = Object();
}

/// Holds and exposes the latest [SyncStatus].
final syncStatusProvider =
    StateNotifierProvider<SyncStatusNotifier, SyncStatus>((ref) {
  return SyncStatusNotifier();
});

class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  SyncStatusNotifier() : super(const SyncStatus());

  void startRound() => state = state.copyWith(syncing: true);

  void applyOutcome(SyncOutcome outcome) {
    if (outcome.ok) {
      state = SyncStatus(
        lastSyncedMs: DateTime.now().millisecondsSinceEpoch,
        pendingCount: outcome.pending,
        lastError: null,
        syncing: false,
      );
    } else {
      state = state.copyWith(
        pendingCount: outcome.pending,
        lastError: outcome.error,
        syncing: false,
      );
    }
  }

  void fail(String error, int pending) {
    state = state.copyWith(lastError: error, pendingCount: pending, syncing: false);
  }
}

/// Shared cursor store (KeyValue table, "sync:" namespace) for push high-water
/// marks, one row per endpoint.
final syncCursorsProvider = Provider<JsonStore>((ref) {
  return JsonStore(ref.watch(databaseProvider), 'sync:');
});

/// Builds the cloud [CloudSync] for the current identity, or null when no cloud
/// base URL is configured (fully-offline build).
final cloudSyncProvider = FutureProvider<CloudSync?>((ref) async {
  final base = ref.watch(cloudBaseUrlProvider).replaceAll(RegExp(r'/+$'), '');
  if (base.isEmpty) return null;
  final id = await ref.watch(identityProvider.future);
  return CloudSync(
    store: ref.watch(eventStoreProvider),
    baseUrl: base,
    http: ref.watch(syncHttpProvider),
    cursors: ref.watch(syncCursorsProvider),
    myAuthorPubkey: Uint8List.fromList(id.keys.signingPublicKey),
    apiKey: ref.watch(cloudApiKeyProvider),
    kind: SyncEndpointKind.cloud,
  );
});

/// Builds the node [CloudSync] for the active saved node, or null when none is
/// saved (node sync is then a no-op, not an error).
final nodeSyncProvider = FutureProvider<CloudSync?>((ref) async {
  final activeId = await ref.watch(activeNodeIdProvider.future);
  if (activeId == null) return null;
  final nodes = await ref.watch(nodesProvider.future);
  final matches = nodes.where((n) => n.id == activeId);
  if (matches.isEmpty) return null;
  final node = matches.first;
  final base = node.url.replaceAll(RegExp(r'/+$'), '');
  if (base.isEmpty) return null;
  final id = await ref.watch(identityProvider.future);
  return CloudSync(
    store: ref.watch(eventStoreProvider),
    baseUrl: base,
    http: ref.watch(syncHttpProvider),
    cursors: ref.watch(syncCursorsProvider),
    myAuthorPubkey: Uint8List.fromList(id.keys.signingPublicKey),
    kind: SyncEndpointKind.node,
  );
});

/// The HTTP seam used by the sync clients. Overridden in tests with a fake.
final syncHttpProvider = Provider<SyncHttp>((ref) => HttpSyncHttp());

/// Coordinates sync: runs the cloud and node rounds, applies pulled events
/// through the EventStore, bumps the world revision so derived state recomputes,
/// and drives periodic + on-demand syncs with exponential backoff on failure.
///
/// Created once (via [syncCoordinatorProvider]) and kept alive by the widget
/// that owns the app lifecycle (see [SyncLifecycleObserver]).
class SyncCoordinator {
  SyncCoordinator(this._ref);

  final Ref _ref;
  Timer? _periodic;
  bool _running = false;
  bool _visible = true;

  /// Current backoff delay; grows on failure, resets on success.
  Duration _backoff = Duration.zero;
  static const Duration _minBackoff = Duration(seconds: 1);
  static const Duration _maxBackoff = Duration(minutes: 2);
  static const Duration _period = Duration(seconds: 30);

  /// Starts background syncing: an immediate round, then every 30s while
  /// visible.
  void start() {
    _schedulePeriodic();
    unawaited(syncNow());
  }

  void _schedulePeriodic() {
    _periodic?.cancel();
    _periodic = Timer.periodic(_period, (_) {
      if (_visible) unawaited(syncNow());
    });
  }

  /// Called when the app's visibility changes (resumed/paused). On resume we
  /// sync immediately; while hidden the periodic timer is a no-op.
  void setVisible(bool visible) {
    final wasVisible = _visible;
    _visible = visible;
    if (visible && !wasVisible) {
      unawaited(syncNow());
    }
  }

  /// Runs one combined (cloud + node) sync round. Coalesces concurrent calls:
  /// if a round is already in flight, this returns without starting another.
  Future<void> syncNow() async {
    if (_running) return;
    _running = true;
    final notifier = _ref.read(syncStatusProvider.notifier);
    notifier.startRound();
    try {
      // Honor any pending backoff before trying again.
      if (_backoff > Duration.zero) {
        await Future<void>.delayed(_backoff);
      }

      SyncOutcome? cloudOut;
      SyncOutcome? nodeOut;

      final cloud = await _ref.read(cloudSyncProvider.future);
      if (cloud != null) {
        cloudOut = await cloud.syncOnce();
      }
      final node = await _ref.read(nodeSyncProvider.future);
      if (node != null) {
        nodeOut = await node.syncOnce();
      }

      final combined = _combine(cloudOut, nodeOut);
      if (combined == null) {
        // No transport configured at all: nothing to do, not an error.
        notifier.applyOutcome(const SyncOutcome());
        _backoff = Duration.zero;
        return;
      }

      // If anything new was applied, recompute derived/world state.
      if (combined.applied > 0) {
        bumpWorldRef(_ref);
      }

      notifier.applyOutcome(combined);

      if (combined.ok) {
        _backoff = Duration.zero;
      } else {
        _growBackoff();
      }
    } catch (e) {
      notifier.fail(_short(e), 0);
      _growBackoff();
    } finally {
      _running = false;
    }
  }

  /// Merges the cloud and node outcomes into one status. Pending is the max of
  /// the two (each transport tracks our own backlog to it); an error from
  /// either transport is surfaced.
  SyncOutcome? _combine(SyncOutcome? a, SyncOutcome? b) {
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    return SyncOutcome(
      pushed: a.pushed + b.pushed,
      applied: a.applied + b.applied,
      rejected: a.rejected + b.rejected,
      pending: a.pending > b.pending ? a.pending : b.pending,
      error: a.error ?? b.error,
    );
  }

  void _growBackoff() {
    if (_backoff == Duration.zero) {
      _backoff = _minBackoff;
    } else {
      final next = _backoff * 2;
      _backoff = next > _maxBackoff ? _maxBackoff : next;
    }
  }

  void dispose() {
    _periodic?.cancel();
    _periodic = null;
  }

  static String _short(Object e) {
    final s = e.toString();
    return s.length > 160 ? '${s.substring(0, 157)}...' : s;
  }
}

/// The single [SyncCoordinator] instance for the app.
final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final c = SyncCoordinator(ref);
  ref.onDispose(c.dispose);
  return c;
});

/// A widget that starts background sync, re-syncs on resume, and re-syncs after
/// every local write (by watching [worldRevisionProvider]). Wrap the app shell
/// with this so sync runs for the whole session.
class SyncLifecycleObserver extends ConsumerStatefulWidget {
  const SyncLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncLifecycleObserver> createState() =>
      _SyncLifecycleObserverState();
}

class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver>
    with WidgetsBindingObserver {
  int _lastRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastRevision = ref.read(worldRevisionProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncCoordinatorProvider).start();
      // Auto-resolve position on start (permission permitting). Never blocks
      // the first paint; a failure quietly leaves the cached last-known fix.
      unawaited(autoResolvePosition(ref));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final coordinator = ref.read(syncCoordinatorProvider);
    final resumed = state == AppLifecycleState.resumed;
    coordinator.setVisible(resumed);
    if (resumed) {
      // Re-resolve position on foreground so the map recentres on a fresh fix.
      unawaited(autoResolvePosition(ref));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // After every local write bumpWorld() increments worldRevisionProvider;
    // trigger a push so our new event reaches the peers promptly.
    ref.listen<int>(worldRevisionProvider, (prev, next) {
      if (next != _lastRevision) {
        _lastRevision = next;
        ref.read(syncCoordinatorProvider).syncNow();
      }
    });
    return widget.child;
  }
}
