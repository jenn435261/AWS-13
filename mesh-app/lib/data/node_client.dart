import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'endpoints.dart';
import 'wire/event_codec.dart';

/// The Node answered with an error, or not in a way the app understands.
class NodeException implements Exception {
  const NodeException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => 'NodeException(${status ?? '-'}): $message';
}

/// The Node's answer to a push: event ids (hex) it stored, and ones it
/// refused because they failed verification.
class NodeAck {
  const NodeAck({this.applied = const {}, this.rejected = const {}});

  final Set<String> applied;
  final Set<String> rejected;
}

/// One author's newest event on the Node (`GET /node/v1/have`).
class NodeHead {
  const NodeHead({
    required this.author,
    required this.highWater,
    required this.headEventId,
  });

  /// Public key, hex.
  final String author;
  final int highWater;
  final String headEventId;
}

/// The Node's folded, public view (`GET /node/v1/state`). Coarse on
/// purpose: no exact positions, no authors, no message text.
class NodeState {
  const NodeState({
    required this.resources,
    required this.alerts,
    required this.requests,
    required this.count,
  });

  final List<Map<String, Object?>> resources;
  final List<Map<String, Object?>> alerts;
  final List<Map<String, Object?>> requests;

  /// Events folded into this view.
  final int count;
}

/// HTTP client for a Resilience Node's sync API on the local network
/// (node/internal/syncserver/server.go on feature/resilience-network).
///
/// Speaks the Node's JSON form of the `resilience.v1` protobuf messages
/// (protojson: camelCase names, bytes in base64, 64-bit numbers as
/// strings). Every event it pushes is signed by this phone; the Node
/// checks each one and refuses anything that fails.
class NodeClient {
  NodeClient({
    String? baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  })  : baseUrl = Uri.parse(baseUrl ?? nodeBaseUrl),
        _http = client ?? http.Client();

  final Uri baseUrl;
  final Duration timeout;
  final http.Client _http;

  static const _json = {'Content-Type': 'application/json', 'Accept': 'application/json'};

  Uri _at(String path) => baseUrl.resolve(path);

  /// `GET /healthz`: true when the Node is there and well.
  Future<bool> healthy() async {
    try {
      final r = await _http.get(_at('/healthz')).timeout(timeout);
      return r.statusCode == 200 && (_decode(r)['status'] == 'ok');
    } on Object {
      return false;
    }
  }

  /// `POST /node/v1/push`: hands over [events]; the Node verifies and
  /// stores each one. Sending an event it already has is fine: it counts
  /// as applied and is not stored twice.
  Future<NodeAck> push(List<WireEvent> events) async {
    final r = await _post('/node/v1/push', {
      'events': [for (final e in events) e.toJson()],
    });
    final ack = (r['ack'] as Map?)?.cast<String, Object?>() ?? const {};
    Set<String> ids(Object? list) => {
          for (final id in (list as List?) ?? const [])
            hexOf(base64.decode(base64.normalize(id as String))),
        };
    return NodeAck(applied: ids(ack['applied']), rejected: ids(ack['rejected']));
  }

  /// `POST /node/v1/pull`: events above each author's watermark in [from]
  /// (author public key hex to lamport). Authors not named come in full.
  Future<List<WireEvent>> pull({Map<String, int> from = const {}, int limit = 0}) async {
    final r = await _post('/node/v1/pull', {
      'from': [
        for (final f in from.entries)
          {'authorPubkey': base64.encode(_unhex(f.key)), 'fromLamport': '${f.value}'},
      ],
      if (limit > 0) 'limit': limit,
    });
    final batch = (r['batch'] as Map?)?.cast<String, Object?>() ?? const {};
    return [
      for (final e in (batch['events'] as List?) ?? const [])
        WireEvent.fromJson((e as Map).cast<String, Object?>()),
    ];
  }

  /// `GET /node/v1/have`: each author's newest event on the Node.
  Future<List<NodeHead>> have() async {
    final r = await _get('/node/v1/have');
    return [
      for (final a in (r['authors'] as List?) ?? const [])
        NodeHead(
          author: (a as Map)['author'] as String? ?? '',
          highWater: (a['high_water'] as num?)?.toInt() ?? 0,
          headEventId: a['head_event_id'] as String? ?? '',
        ),
    ];
  }

  /// `GET /node/v1/state`: what the Node's own offline web page shows.
  Future<NodeState> state() async {
    final r = await _get('/node/v1/state');
    List<Map<String, Object?>> list(String key) => [
          for (final x in (r[key] as List?) ?? const []) (x as Map).cast<String, Object?>(),
        ];
    return NodeState(
      resources: list('resources'),
      alerts: list('alerts'),
      requests: list('requests'),
      count: (r['count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Map<String, Object?>> _get(String path) async {
    final r = await _http.get(_at(path), headers: _json).timeout(timeout);
    return _checked(r);
  }

  Future<Map<String, Object?>> _post(String path, Map<String, Object?> body) async {
    final r = await _http
        .post(_at(path), headers: _json, body: jsonEncode(body))
        .timeout(timeout);
    return _checked(r);
  }

  Map<String, Object?> _checked(http.Response r) {
    final body = _decode(r);
    if (r.statusCode != 200) {
      throw NodeException(body['error'] as String? ?? r.reasonPhrase ?? 'error', status: r.statusCode);
    }
    return body;
  }

  static Map<String, Object?> _decode(http.Response r) {
    try {
      final v = jsonDecode(utf8.decode(r.bodyBytes));
      return v is Map ? v.cast<String, Object?>() : const {};
    } on FormatException {
      throw NodeException('not JSON', status: r.statusCode);
    }
  }

  static List<int> _unhex(String hex) => [
        for (var i = 0; i + 1 < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
      ];

  void close() => _http.close();
}
