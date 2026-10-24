import '../alert_client.dart';
import '../alert_notifier.dart';

/// Native / unsupported-platform notifier.
///
/// A true native local notification needs a platform plugin
/// (flutter_local_notifications) AND a real device to observe; this sandbox has
/// neither, and that plugin must never be imported into the web build. So this
/// stub is HONEST: it reports notifications unavailable and shows nothing at the
/// OS level. The in-app banner (driven by AlertPoller.state) still appears, so
/// the user is never left unaware of a severe alert while the app is open.
/// Wiring a real native local notification is a device-only follow-up (see
/// docs/DECISIONS.md FEAT-004 §5.3).
class _StubAlertNotifier implements AlertNotifier {
  @override
  bool get available => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> notifySevere(FeedAlert alert) async => false;
}

AlertNotifier createAlertNotifier() => _StubAlertNotifier();
