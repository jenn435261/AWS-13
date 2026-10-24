import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'alert_client.dart';
import 'alert_notifier.dart';
import 'alert_poller.dart';

/// Default radius (km) for the region alert poll, centered on the user's
/// current/home position. A coarse radius keeps the query useful without
/// leaking a precise location (the server only ever gets the rounded point).
const double kAlertRadiusKm = 150;

/// The HTTP seam the alert client uses. Overridden in tests with a fake.
final alertHttpProvider = Provider<AlertHttp>((ref) => HttpAlertHttp());

/// The platform notifier (web Notifications API; honest no-op on native/
/// unsupported). Overridden in tests with a recording double.
final alertNotifierProvider =
    Provider<AlertNotifier>((ref) => defaultAlertNotifier());

/// Builds an [AlertClient] for the configured cloud base URL, or null when the
/// build is fully offline (no cloud).
AlertClient? buildAlertClient(Ref ref) {
  final base = ref.read(cloudBaseUrlProvider).replaceAll(RegExp(r'/+$'), '');
  if (base.isEmpty) return null;
  return AlertClient(
    baseUrl: base,
    http: ref.read(alertHttpProvider),
    apiKey: ref.read(cloudApiKeyProvider),
  );
}

/// The single [AlertPoller]. It polls the cloud for alerts near the user's
/// current position (falling back to a region-less poll when no position is
/// known) while the app is open, raises a notification + banner on a new severe
/// alert, and exposes [AlertState]. Kept alive for the session by the shell.
final alertPollerProvider = Provider<AlertPoller?>((ref) {
  // A fully-offline build (no cloud) has nothing to poll.
  final base = ref.read(cloudBaseUrlProvider).replaceAll(RegExp(r'/+$'), '');
  if (base.isEmpty) return null;

  final poller = AlertPoller(
    clientFactory: () => buildAlertClient(ref)!,
    notifier: ref.read(alertNotifierProvider),
    regionProvider: () {
      final pos = ref.read(myPositionProvider);
      if (pos == null) return null;
      return (lat: pos.latitude, lon: pos.longitude, radiusKm: kAlertRadiusKm);
    },
  );
  poller.onChange = (s) => ref.read(alertStateProvider.notifier).state = s;
  ref.onDispose(poller.dispose);
  return poller;
});

/// The latest [AlertState] for the UI (banner + alerts list).
final alertStateProvider =
    StateProvider<AlertState>((ref) => const AlertState());
