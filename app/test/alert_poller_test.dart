import 'dart:convert';
import 'dart:typed_data';

import 'package:resilience/alerts/alert_client.dart';
import 'package:resilience/alerts/alert_notifier.dart';
import 'package:resilience/alerts/alert_poller.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake alert transport returning a scripted sequence of responses, so the
/// poller is exercised with NO real network.
class _FakeAlertHttp implements AlertHttp {
  _FakeAlertHttp(this.responses);
  final List<Map<String, dynamic>> responses;
  int _i = 0;

  @override
  Future<AlertHttpResponse> get(Uri url, Map<String, String> headers) async {
    final body = responses[_i.clamp(0, responses.length - 1)];
    _i++;
    return AlertHttpResponse(200, utf8.encode(jsonEncode(body)));
  }
}

Map<String, dynamic> _alert(String id, String priority,
        {int createdMs = 1000}) =>
    {
      'alert_id': id,
      'title': 'Alert $id',
      'detail': '[official_feed:nws]\nsomething',
      'priority': priority,
      'source': 'official_feed:nws',
      'lat': 37.7,
      'lon': -122.4,
      'distance_km': 1.0,
      'created_ms': createdMs,
      'expires_ms': 9999999999999,
      'age_ms': 10,
    };

void main() {
  group('newestNewSevere', () {
    test('returns the newest unseen severe alert only', () {
      final alerts = [
        FeedAlert.fromJson(_alert('a', 'PRIORITY_HIGH', createdMs: 100))!,
        FeedAlert.fromJson(_alert('b', 'PRIORITY_CRITICAL', createdMs: 300))!,
        FeedAlert.fromJson(_alert('c', 'PRIORITY_LOW', createdMs: 400))!,
      ];
      // None seen: newest severe is b (critical, created 300). c is not severe.
      final got = newestNewSevere(alerts, {});
      expect(got?.alertId, 'b');
      // Once b is seen, a is the only remaining severe.
      final got2 = newestNewSevere(alerts, {'b'});
      expect(got2?.alertId, 'a');
      // All seen => null.
      expect(newestNewSevere(alerts, {'a', 'b', 'c'}), isNull);
    });

    test('ignores non-severe alerts entirely', () {
      final alerts = [
        FeedAlert.fromJson(_alert('x', 'PRIORITY_NORMAL'))!,
        FeedAlert.fromJson(_alert('y', 'PRIORITY_LOW'))!,
      ];
      expect(newestNewSevere(alerts, {}), isNull);
    });
  });

  group('AlertPoller', () {
    test('first poll does not notify for pre-existing alerts', () async {
      final http = _FakeAlertHttp([
        {
          'alerts': [_alert('a', 'PRIORITY_CRITICAL')],
          'feed_pubkey': 'abcd'
        },
      ]);
      final notifier = NoopAlertNotifier();
      final poller = AlertPoller(
        clientFactory: () =>
            AlertClient(baseUrl: 'https://c', http: http),
        notifier: notifier,
        regionProvider: () => null,
      );
      final severe = await poller.pollOnce();
      expect(severe, isNull, reason: 'launch alerts must not notify');
      expect(notifier.notified, isEmpty);
      expect(poller.state.alerts.length, 1);
      expect(poller.state.feedPubkey, 'abcd');
    });

    test('a severe alert appearing in a later poll notifies + banners',
        () async {
      final http = _FakeAlertHttp([
        // First poll: one normal alert (becomes "seen").
        {
          'alerts': [_alert('a', 'PRIORITY_NORMAL')],
          'feed_pubkey': 'abcd'
        },
        // Second poll: a NEW critical alert.
        {
          'alerts': [
            _alert('a', 'PRIORITY_NORMAL'),
            _alert('b', 'PRIORITY_CRITICAL', createdMs: 2000),
          ],
          'feed_pubkey': 'abcd'
        },
      ]);
      final notifier = NoopAlertNotifier();
      final poller = AlertPoller(
        clientFactory: () => AlertClient(baseUrl: 'https://c', http: http),
        notifier: notifier,
        regionProvider: () => (lat: 37.7, lon: -122.4, radiusKm: 100),
      );
      await poller.pollOnce();
      expect(poller.state.pendingSevere, isNull);

      final severe = await poller.pollOnce();
      expect(severe?.alertId, 'b');
      // The notifier was asked to notify (even though the noop shows nothing).
      expect(notifier.notified.single.alertId, 'b');
      // The banner is driven off pendingSevere.
      expect(poller.state.pendingSevere?.alertId, 'b');

      // Dismiss clears the banner.
      poller.dismissPending();
      expect(poller.state.pendingSevere, isNull);
    });

    test('a poll error is surfaced honestly, not thrown', () async {
      final poller = AlertPoller(
        clientFactory: () => AlertClient(
            baseUrl: 'https://c', http: _ErrHttp()),
        notifier: NoopAlertNotifier(),
        regionProvider: () => null,
      );
      final severe = await poller.pollOnce();
      expect(severe, isNull);
      expect(poller.state.error, isNotNull);
    });
  });
}

class _ErrHttp implements AlertHttp {
  @override
  Future<AlertHttpResponse> get(Uri url, Map<String, String> headers) async {
    return AlertHttpResponse(503, Uint8List(0));
  }
}
