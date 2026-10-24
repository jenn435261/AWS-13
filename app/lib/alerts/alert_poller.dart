import 'dart:async';

import 'alert_client.dart';
import 'alert_notifier.dart';

/// Immutable state the alert UI reads: the current alerts for the user's
/// regions, the newest SEVERE alert not yet dismissed (drives the in-app banner
/// + "Prepare now" button), whether the feed root is trusted, and an honest
/// error/limit string.
class AlertState {
  final List<FeedAlert> alerts;

  /// The severe alert to show in the banner, or null when none is pending.
  final FeedAlert? pendingSevere;

  /// The cloud feed public key last seen (the trusted root). Empty => the
  /// deployment advertised no feed, so alerts cannot be labelled Official.
  final String feedPubkey;

  /// A truthful short error/limit, or null. Never a stack trace.
  final String? error;

  const AlertState({
    this.alerts = const [],
    this.pendingSevere,
    this.feedPubkey = '',
    this.error,
  });

  AlertState copyWith({
    List<FeedAlert>? alerts,
    Object? pendingSevere = _sentinel,
    String? feedPubkey,
    Object? error = _sentinel,
  }) =>
      AlertState(
        alerts: alerts ?? this.alerts,
        pendingSevere: identical(pendingSevere, _sentinel)
            ? this.pendingSevere
            : pendingSevere as FeedAlert?,
        feedPubkey: feedPubkey ?? this.feedPubkey,
        error: identical(error, _sentinel) ? this.error : error as String?,
      );

  static const Object _sentinel = Object();
}

/// Detects which alerts in a fresh poll are NEW relative to a set of
/// already-seen alert ids, and returns the newest severe one among them. Pure
/// and deterministic so it is unit-testable without any platform dependency.
///
/// "Newest" = highest createdMs, tie-broken by alertId for stability. Only a
/// severe alert (CRITICAL/HIGH) triggers a notification + banner.
FeedAlert? newestNewSevere(List<FeedAlert> fresh, Set<String> seenIds) {
  FeedAlert? best;
  for (final a in fresh) {
    if (seenIds.contains(a.alertId) || !a.isSevere) continue;
    if (best == null ||
        a.createdMs > best.createdMs ||
        (a.createdMs == best.createdMs && a.alertId.compareTo(best.alertId) > 0)) {
      best = a;
    }
  }
  return best;
}

/// Drives alert polling while the app is online + foregrounded and detects new
/// severe alerts. On a new severe alert it raises a platform notification (via
/// the injected [AlertNotifier], a no-op/honest-limit on web) and exposes the
/// alert as [AlertState.pendingSevere] so the UI shows an in-app banner with a
/// "Prepare now" button.
///
/// Native background polling (workmanager / BG fetch) is a separate concern
/// wired in the platform layer; this poller covers the foreground/web-open case
/// the plan requires and is fully testable with a fake [AlertClient] transport.
class AlertPoller {
  AlertPoller({
    required AlertClient Function() clientFactory,
    required AlertNotifier notifier,
    required this.regionProvider,
    this.period = const Duration(minutes: 2),
  })  : _clientFactory = clientFactory,
        _notifier = notifier;

  final AlertClient Function() _clientFactory;
  final AlertNotifier _notifier;

  /// Supplies the region to poll (current/home/saved): (lat, lon, radiusKm).
  /// Returns null when no region is known (then a region-less poll fetches all
  /// current feed alerts).
  final ({double lat, double lon, double radiusKm})? Function() regionProvider;

  final Duration period;

  final Set<String> _seen = <String>{};
  Timer? _timer;
  bool _started = false;

  /// The latest state. Replaced on each poll; a listener (the provider) surfaces
  /// it to the UI.
  AlertState state = const AlertState();

  /// Called whenever [state] changes.
  void Function(AlertState)? onChange;

  /// Starts periodic polling (an immediate poll, then every [period]).
  void start() {
    if (_started) return;
    _started = true;
    unawaited(pollOnce());
    _timer = Timer.periodic(period, (_) => unawaited(pollOnce()));
  }

  /// Runs a single poll. On the FIRST poll, every current alert is treated as
  /// already-seen (we do not notify for pre-existing alerts on launch); only
  /// alerts appearing in a LATER poll raise a notification. Returns the new
  /// severe alert that was detected, or null.
  Future<FeedAlert?> pollOnce() async {
    final client = _clientFactory();
    final region = regionProvider();
    final res = await client.poll(
      lat: region?.lat,
      lon: region?.lon,
      radiusKm: region?.radiusKm ?? 0,
    );
    if (res.error != null) {
      _emit(state.copyWith(error: res.error));
      return null;
    }

    final firstPoll = _seen.isEmpty && state.alerts.isEmpty;
    FeedAlert? severe;
    if (!firstPoll) {
      severe = newestNewSevere(res.alerts, _seen);
    }
    for (final a in res.alerts) {
      _seen.add(a.alertId);
    }

    if (severe != null) {
      await _notifier.notifySevere(severe);
    }
    _emit(AlertState(
      alerts: res.alerts,
      pendingSevere: severe ?? state.pendingSevere,
      feedPubkey: res.feedPubkey,
      error: null,
    ));
    return severe;
  }

  /// Dismisses the current banner (user acted on or closed it).
  void dismissPending() {
    _emit(state.copyWith(pendingSevere: null));
  }

  void _emit(AlertState next) {
    state = next;
    onChange?.call(next);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
