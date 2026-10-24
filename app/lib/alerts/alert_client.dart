import 'dart:convert';

import 'package:http/http.dart' as http;

/// One official-feed alert as returned by the cloud `GET /v1/alerts`. Every
/// field is server-reported from a stored, verified event — the app never
/// fabricates an alert. [source] names the feed (e.g. `official_feed:nws`),
/// [ageMs] lets the UI freshness-decay it, and [priority] drives the severe
/// detection that raises a notification + banner.
class FeedAlert {
  final String alertId;
  final String title;
  final String detail;
  final String priority; // e.g. PRIORITY_CRITICAL / PRIORITY_HIGH / ...
  final String source;
  final double lat;
  final double lon;
  final double distanceKm;
  final int createdMs;
  final int expiresMs;
  final int ageMs;

  const FeedAlert({
    required this.alertId,
    required this.title,
    required this.detail,
    required this.priority,
    required this.source,
    required this.lat,
    required this.lon,
    required this.distanceKm,
    required this.createdMs,
    required this.expiresMs,
    required this.ageMs,
  });

  /// A SEVERE alert is one the app should notify + banner about: the two
  /// highest proto priority bands (CRITICAL / HIGH).
  bool get isSevere =>
      priority == 'PRIORITY_CRITICAL' || priority == 'PRIORITY_HIGH';

  static FeedAlert? fromJson(Map<String, dynamic> j) {
    final id = j['alert_id'];
    if (id is! String || id.isEmpty) return null;
    return FeedAlert(
      alertId: id,
      title: j['title'] as String? ?? '',
      detail: j['detail'] as String? ?? '',
      priority: j['priority'] as String? ?? 'PRIORITY_UNSPECIFIED',
      source: j['source'] as String? ?? '',
      lat: (j['lat'] as num?)?.toDouble() ?? 0,
      lon: (j['lon'] as num?)?.toDouble() ?? 0,
      distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
      createdMs: (j['created_ms'] as num?)?.toInt() ?? 0,
      expiresMs: (j['expires_ms'] as num?)?.toInt() ?? 0,
      ageMs: (j['age_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The result of one alert poll: the alerts and the server's advertised feed
/// public key (the trusted root the app uses to label them Official).
class AlertPollResult {
  final List<FeedAlert> alerts;
  final String feedPubkey;
  final String? error;
  const AlertPollResult(
      {this.alerts = const [], this.feedPubkey = '', this.error});
}

/// The minimal HTTP seam the alert client needs. Injecting it lets tests drive a
/// fake transport with no real network, mirroring [SyncHttp].
abstract class AlertHttp {
  Future<AlertHttpResponse> get(Uri url, Map<String, String> headers);
}

class AlertHttpResponse {
  final int statusCode;
  final List<int> body;
  const AlertHttpResponse(this.statusCode, this.body);
}

/// Default [AlertHttp] backed by the `http` package with a timeout.
class HttpAlertHttp implements AlertHttp {
  HttpAlertHttp({http.Client? client, this.timeout = const Duration(seconds: 10)})
      : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;

  @override
  Future<AlertHttpResponse> get(Uri url, Map<String, String> headers) async {
    final r = await _client.get(url, headers: headers).timeout(timeout);
    return AlertHttpResponse(r.statusCode, r.bodyBytes);
  }
}

/// Polls the cloud `GET /v1/alerts` for a region. Never throws: a failure is
/// captured in [AlertPollResult.error] so the UI can stay honest.
class AlertClient {
  AlertClient({
    required this.baseUrl,
    required AlertHttp http,
    this.apiKey = '',
  }) : _http = http;

  final String baseUrl; // no trailing slash
  final AlertHttp _http;
  final String apiKey;

  /// Polls alerts near ([lat],[lon]) within [radiusKm]. When [sinceMs] > 0 only
  /// alerts created strictly after it are returned. Any of lat/lon/radius may be
  /// omitted (null) to fetch all current feed alerts.
  Future<AlertPollResult> poll({
    double? lat,
    double? lon,
    double radiusKm = 0,
    int sinceMs = 0,
  }) async {
    final params = <String, String>{};
    if (lat != null) params['lat'] = lat.toString();
    if (lon != null) params['lon'] = lon.toString();
    if (radiusKm > 0) params['radius_km'] = radiusKm.toString();
    if (sinceMs > 0) params['since'] = sinceMs.toString();
    final uri = Uri.parse('$baseUrl/v1/alerts').replace(queryParameters: params);
    final headers = <String, String>{'Accept': 'application/json'};
    if (apiKey.isNotEmpty) headers['X-Api-Key'] = apiKey;
    try {
      final r = await _http.get(uri, headers);
      if (r.statusCode != 200) {
        return AlertPollResult(error: 'HTTP ${r.statusCode}');
      }
      final decoded = jsonDecode(utf8.decode(r.body));
      if (decoded is! Map) return const AlertPollResult(error: 'bad response');
      final list = (decoded['alerts'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FeedAlert.fromJson)
          .whereType<FeedAlert>()
          .toList();
      return AlertPollResult(
        alerts: list,
        feedPubkey: decoded['feed_pubkey'] as String? ?? '',
      );
    } catch (e) {
      return AlertPollResult(error: _short(e));
    }
  }

  static String _short(Object e) {
    final s = e.toString();
    return s.length > 120 ? '${s.substring(0, 117)}...' : s;
  }
}
