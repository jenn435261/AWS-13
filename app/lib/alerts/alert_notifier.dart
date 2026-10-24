import 'alert_client.dart';
import 'notifier/stub.dart'
    if (dart.library.js_interop) 'notifier/web.dart' as platform;

/// Raises a platform notification for a new severe alert. The in-app banner is
/// driven separately by [AlertPoller.state]; this seam is ONLY the OS-level
/// notification. It is honest about platform limits: on web it uses the
/// Notifications API when (and only when) the user has granted permission, and
/// it NEVER claims to have notified when it could not.
abstract class AlertNotifier {
  /// Whether OS notifications are actually available+permitted right now.
  bool get available;

  /// Attempts to request notification permission (web only). Returns the
  /// resulting availability. A no-op elsewhere.
  Future<bool> requestPermission();

  /// Raises a notification for [alert]. Returns true if one was actually shown.
  Future<bool> notifySevere(FeedAlert alert);
}

/// The platform-appropriate notifier (web Notifications API, honest no-op on
/// native/unsupported where a real local-notification plugin + device are
/// required — see docs/DECISIONS.md FEAT-004 §5.3).
AlertNotifier defaultAlertNotifier() => platform.createAlertNotifier();

/// A notifier that never shows anything but records calls (for tests + the
/// honest "notifications unavailable" state).
class NoopAlertNotifier implements AlertNotifier {
  final List<FeedAlert> notified = <FeedAlert>[];
  @override
  bool get available => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<bool> notifySevere(FeedAlert alert) async {
    notified.add(alert);
    return false;
  }
}
