import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'online_detector/online_detector.dart';
import 'sync_providers.dart';

/// What the app can honestly say about its connectivity right now. Each state
/// is derived from something actually measured (a real reachability result from
/// the sync client and/or the browser online/offline flag), so the banner never
/// claims a capability that is not wired.
enum Connectivity {
  /// The cloud API responded on the last sync round (we are reaching the
  /// internet backend).
  online,

  /// A cloud base URL is configured and we are (browser) online, but the last
  /// sync round to the cloud failed — the backend is unreachable right now.
  cloudUnreachable,

  /// A Resilience Node is configured and reachable, but the cloud is not — we
  /// are working off a local node (local-network coordination).
  nodeConnected,

  /// No backend reached: either no cloud is configured, or the browser reports
  /// offline. The app still works on local data only.
  offline,
}

/// The inputs the connectivity state machine folds into a [Connectivity]. All
/// come from real measurements, never assumptions.
class ConnectivityInputs {
  /// True when a cloud base URL is configured for this build.
  final bool cloudConfigured;

  /// True when an active Resilience Node is saved.
  final bool nodeConfigured;

  /// The browser online flag, or null when it cannot be observed (native).
  final bool? browserOnline;

  /// The last sync round reached a backend cleanly (cloud and/or node).
  final bool lastSyncOk;

  /// There is a recorded sync error from the last round.
  final bool hadSyncError;

  /// We have never completed a sync round yet.
  final bool neverSynced;

  const ConnectivityInputs({
    required this.cloudConfigured,
    required this.nodeConfigured,
    required this.browserOnline,
    required this.lastSyncOk,
    required this.hadSyncError,
    required this.neverSynced,
  });

  /// The pure state machine. Order matters: a confirmed clean sync to the cloud
  /// is the strongest signal; a hard "browser offline" is the next strongest
  /// (we cannot reach anything over the internet); otherwise we distinguish a
  /// reachable node from an unreachable cloud.
  Connectivity resolve() {
    // Browser says we are offline => we truly cannot reach the internet. If a
    // local node is configured we may still reach it over local Wi-Fi, but the
    // browser offline flag only covers internet; be honest and show offline
    // unless a node round actually succeeded.
    if (browserOnline == false && !(nodeConfigured && lastSyncOk)) {
      return Connectivity.offline;
    }

    if (!cloudConfigured && !nodeConfigured) {
      return Connectivity.offline;
    }

    if (lastSyncOk) {
      // A clean round reached a backend. Prefer "online" when the cloud is the
      // configured backend; otherwise it was a node round.
      if (cloudConfigured) return Connectivity.online;
      return Connectivity.nodeConnected;
    }

    // No clean round yet (error, or never synced).
    if (nodeConfigured && !cloudConfigured) {
      // Only a node is configured and we have not confirmed it; treat an error
      // as offline, a pending first round as node-connected-pending => offline
      // is safer than claiming connection.
      return hadSyncError ? Connectivity.offline : Connectivity.nodeConnected;
    }

    if (cloudConfigured && hadSyncError) {
      return Connectivity.cloudUnreachable;
    }

    // Cloud configured, browser online (or unknown), no error yet (first round
    // in flight): we have not confirmed reachability, so do not claim online.
    return neverSynced ? Connectivity.cloudUnreachable : Connectivity.online;
  }
}

/// A single [OnlineDetector] for the app's lifetime.
final onlineDetectorProvider = Provider<OnlineDetector>((ref) {
  final d = OnlineDetector();
  ref.onDispose(d.dispose);
  return d;
});

/// The live browser online flag (web), or null when not observable (native).
/// Updates whenever the browser emits an online/offline event, so the banner
/// flips without a reload.
final browserOnlineProvider = StreamProvider<bool?>((ref) {
  final detector = ref.watch(onlineDetectorProvider);
  return detector.changes.map<bool?>((v) => v);
});

/// The current honest connectivity state, recomputed whenever the sync status
/// or the browser online flag changes.
final connectivityProvider = Provider<Connectivity>((ref) {
  final sync = ref.watch(syncStatusProvider);
  final cloud = ref.watch(cloudBaseUrlProvider).isNotEmpty;
  final activeNode = ref.watch(activeNodeIdProvider).valueOrNull;
  final browserOnline =
      ref.watch(browserOnlineProvider).valueOrNull ??
          ref.watch(onlineDetectorProvider).isOnline;

  final inputs = ConnectivityInputs(
    cloudConfigured: cloud,
    nodeConfigured: activeNode != null,
    browserOnline: browserOnline,
    lastSyncOk: sync.lastSyncedMs != null && sync.lastError == null,
    hadSyncError: sync.lastError != null,
    neverSynced: sync.lastSyncedMs == null && sync.lastError == null,
  );
  return inputs.resolve();
});

/// A short l10n key for the current connectivity state (resolved by the UI).
String connectivityLabelKey(Connectivity c) {
  switch (c) {
    case Connectivity.online:
      return 'conn_online';
    case Connectivity.cloudUnreachable:
      return 'conn_cloud_unreachable';
    case Connectivity.nodeConnected:
      return 'conn_node';
    case Connectivity.offline:
      return 'conn_offline';
  }
}
