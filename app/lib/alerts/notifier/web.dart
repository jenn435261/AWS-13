import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../alert_client.dart';
import '../alert_notifier.dart';

/// Web notifier using the browser Notifications API. It shows a notification
/// ONLY when the user has granted permission; otherwise it reports unavailable
/// honestly (the in-app banner still covers the open-tab case). Web Push/VAPID
/// (background push when the tab is closed) is NOT implemented — that needs a
/// service-worker push subscription + a server push endpoint; the honest limit
/// is stated in the UI and docs rather than faked.
class _WebAlertNotifier implements AlertNotifier {
  @override
  bool get available => web.Notification.permission == 'granted';

  @override
  Future<bool> requestPermission() async {
    try {
      if (web.Notification.permission == 'granted') return true;
      if (web.Notification.permission == 'denied') return false;
      final result = await web.Notification.requestPermission().toDart;
      return result.toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> notifySevere(FeedAlert alert) async {
    if (web.Notification.permission != 'granted') return false;
    try {
      final opts = web.NotificationOptions(
        body: alert.detail.isEmpty ? alert.source : alert.detail,
        tag: alert.alertId,
      );
      web.Notification(
        alert.title.isEmpty ? 'Severe alert' : alert.title,
        opts,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

AlertNotifier createAlertNotifier() => _WebAlertNotifier();
