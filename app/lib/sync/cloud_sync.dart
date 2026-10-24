import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:http/http.dart' as http;

import '../core/event_store.dart';
import '../db/json_store.dart';
import '../gen/resilience/v1/event.pb.dart';
import '../gen/resilience/v1/sync.pb.dart';

/// Result of a single sync round against one transport (cloud or node).
///
/// This is honest, measurable state: how many events we pushed, how many new
/// events we applied (verified-then-stored), how many were rejected by
/// verification, and the error (if any). A caller can surface
/// "Last synced / N pending / error" straight from these fields.
class SyncOutcome {
  /// Number of our own events uploaded to the peer this round.
  final int pushed;

  /// Number of newly-applied events pulled from the peer (passed verification
  /// and were not duplicates).
  final int applied;

  /// Number of pulled events that FAILED verification and were NOT stored
  /// (the forged/tampered-event abuse case).
  final int rejected;

  /// Number of our own events still above the push high-water (not yet
  /// confirmed uploaded). 0 means everything local is on the peer.
  final int pending;

  /// A human-meaningful error, or null on success. Never a stack trace.
  final String? error;

  const SyncOutcome({
    this.pushed = 0,
    this.applied = 0,
    this.rejected = 0,
    this.pending = 0,
    this.error,
  });

  bool get ok => error == null;

  SyncOutcome copyWith({
    int? pushed,
    int? applied,
    int? rejected,
    int? pending,
    String? error,
  }) =>
      SyncOutcome(
        pushed: pushed ?? this.pushed,
        applied: applied ?? this.applied,
        rejected: rejected ?? this.rejected,
        pending: pending ?? this.pending,
        error: error,
      );

  @override
  String toString() =>
      'SyncOutcome(pushed: $pushed, applied: $applied, rejected: $rejected, '
      'pending: $pending, error: $error)';
}

/// The minimal HTTP seam the sync client needs. Injecting this lets tests drive
/// a fake transport (an in-process cloud/node) with no real network, mirroring
/// the fake-transport pattern used by the local gossip [SyncEngine] tests.
abstract class SyncHttp {
  /// POSTs [body] (already JSON-encoded) to [url] with the given [headers] and
  /// returns the response. Implementations MUST apply a timeout so a dead
  /// endpoint never hangs the app.
  Future<SyncHttpResponse> post(
    Uri url,
    Map<String, String> headers,
    List<int> body,
  );
}

/// A tiny, transport-agnostic HTTP response (status + body bytes).
class SyncHttpResponse {
  final int statusCode;
  final List<int> body;
  const SyncHttpResponse(this.statusCode, this.body);
}

/// Default [SyncHttp] backed by the `http` package, with a request timeout so a
/// down API or an unreachable node fails fast instead of spinning forever.
class HttpSyncHttp implements SyncHttp {
  HttpSyncHttp({http.Client? client, this.timeout = const Duration(seconds: 10)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  @override
  Future<SyncHttpResponse> post(
    Uri url,
    Map<String, String> headers,
    List<int> body,
  ) async {
    final r = await _client.post(url, headers: headers, body: body).timeout(timeout);
    return SyncHttpResponse(r.statusCode, r.bodyBytes);
  }
}

/// Names a sync target: the cloud API (`/v1/events`, `/v1/events/pull`) or a
/// Resilience node (`/node/v1/push`, `/node/v1/pull`).
enum SyncEndpointKind { cloud, node }

/// A one-shot sync client against a single HTTP peer (the cloud or a node).
///
/// Each [syncOnce] call runs the reconciliation in two legs, on the wire as
/// JSON (the cloud and node both content-negotiate protobuf-or-JSON, and JSON
/// is the most portable and web-friendly choice):
///
///  1. PULL: send our per-author high-water digest as a [PullEventsRequest];
///     every returned event is ingested through [EventStore.apply] (the single
///     verify-then-store path) so forged/tampered events are rejected and the
///     Lamport clock advances.
///  2. PUSH: upload our own events above the stored per-endpoint push
///     high-water as a [PushEventsRequest].
///
/// Cursors (the per-endpoint push high-water) live in the KeyValue table via
/// [JsonStore] so repeated syncs are incremental and idempotent.
class CloudSync {
  CloudSync({
    required EventStore store,
    required this.baseUrl,
    required SyncHttp http,
    required JsonStore cursors,
    required this.myAuthorPubkey,
    this.apiKey = '',
    this.kind = SyncEndpointKind.cloud,
    this.batchLimit = 500,
  })  : _store = store,
        _http = http,
        _cursors = cursors;

  final EventStore _store;
  final SyncHttp _http;
  final JsonStore _cursors;

  /// Base URL with no trailing slash (e.g. `https://api.example.com`).
  final String baseUrl;

  /// Shared client key for the cloud's `X-Api-Key` gate. Empty => no header.
  final String apiKey;

  /// Our own author public key (32 bytes). Used to compute the pending count.
  final Uint8List myAuthorPubkey;

  final SyncEndpointKind kind;
  final int batchLimit;

  String get _pullPath =>
      kind == SyncEndpointKind.cloud ? '/v1/events/pull' : '/node/v1/pull';
  String get _pushPath =>
      kind == SyncEndpointKind.cloud ? '/v1/events' : '/node/v1/push';

  /// Cursor key is namespaced by endpoint so the cloud and each node keep
  /// independent push high-water marks.
  String get _cursorId => 'pushhw:${kind.name}:$baseUrl';

  Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (apiKey.isNotEmpty) h['X-Api-Key'] = apiKey;
    return h;
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// Runs one pull+push round. Never throws: any failure (API down, node
  /// unreachable, bad response) is captured in [SyncOutcome.error] so the UI
  /// can show a truthful message.
  Future<SyncOutcome> syncOnce() async {
    int applied = 0;
    int rejected = 0;
    int pushed = 0;
    try {
      // --- PULL leg ---
      final pullReq = await _buildPullRequest();
      final pullResp = await _http.post(
        _uri(_pullPath),
        _headers,
        utf8.encode(jsonEncode(pullReq.toProto3Json())),
      );
      if (pullResp.statusCode != 200) {
        return SyncOutcome(
          pending: await _pendingCount(),
          error: _httpError('pull', pullResp),
        );
      }
      final pullBody =
          PullEventsResponse.create()..mergeFromProto3Json(_decode(pullResp.body));
      final events = pullBody.batch.events;
      final results = await _store.applyAll(events);
      for (final r in results) {
        if (r.isApplied) applied++;
        if (r.isInvalid) rejected++;
      }

      // --- PUSH leg ---
      final toPush = await _eventsToPush();
      if (toPush.isNotEmpty) {
        final pushReq = PushEventsRequest(events: toPush);
        final pushResp = await _http.post(
          _uri(_pushPath),
          _headers,
          utf8.encode(jsonEncode(pushReq.toProto3Json())),
        );
        if (pushResp.statusCode != 200) {
          return SyncOutcome(
            applied: applied,
            rejected: rejected,
            pending: await _pendingCount(),
            error: _httpError('push', pushResp),
          );
        }
        // Advance the push high-water only for events the peer ACKed as
        // applied (or that it already had — a duplicate is still "on the
        // peer"). We advance to the max lamport we attempted, since the peer
        // rejecting our OWN valid events would itself be a bug worth surfacing.
        pushed = toPush.length;
        await _advancePushHighWater(toPush);
      }

      return SyncOutcome(
        pushed: pushed,
        applied: applied,
        rejected: rejected,
        pending: await _pendingCount(),
      );
    } on TimeoutException {
      return SyncOutcome(
        applied: applied,
        rejected: rejected,
        pending: await _pendingCount(),
        error: 'timeout',
      );
    } catch (e) {
      return SyncOutcome(
        applied: applied,
        rejected: rejected,
        pending: await _pendingCount(),
        error: _short(e),
      );
    }
  }

  /// Builds the pull request from our per-author high-water digest. For each
  /// author we hold, we ask the peer for everything strictly above our
  /// watermark, so pulls are incremental.
  Future<PullEventsRequest> _buildPullRequest() async {
    final digest = await _store.highWaterByAuthor();
    final from = <PullEventsRequest_AuthorFrom>[];
    digest.forEach((author, hw) {
      from.add(PullEventsRequest_AuthorFrom(
        authorPubkey: author.bytes,
        fromLamport: Int64(hw),
      ));
    });
    return PullEventsRequest(from: from, limit: batchLimit);
  }

  /// Our own events whose lamport exceeds the stored per-endpoint push
  /// high-water. These are what the peer is missing from us.
  Future<List<SignedEvent>> _eventsToPush() async {
    final hw = await _loadPushHighWater();
    return _store.dao.eventsByAuthorFrom(myAuthorPubkey, hw);
  }

  /// N pending = count of our own events above the push high-water.
  Future<int> _pendingCount() async {
    return (await _eventsToPush()).length;
  }

  Future<int> _loadPushHighWater() async {
    final rows = await _cursors.all();
    for (final r in rows) {
      if (r['id'] == _cursorId) {
        final v = r['hw'];
        if (v is num) return v.toInt();
      }
    }
    return 0;
  }

  Future<void> _advancePushHighWater(List<SignedEvent> pushed) async {
    int max = await _loadPushHighWater();
    for (final e in pushed) {
      final l = e.header.lamport.toInt();
      if (l > max) max = l;
    }
    await _cursors.put(_cursorId, {'id': _cursorId, 'hw': max});
  }

  static String _httpError(String leg, SyncHttpResponse r) {
    // Try to surface the server's structured {"error": "..."} message.
    try {
      final j = jsonDecode(utf8.decode(r.body));
      if (j is Map && j['error'] is String) {
        return '$leg ${r.statusCode}: ${j['error']}';
      }
    } catch (_) {}
    return '$leg failed (HTTP ${r.statusCode})';
  }

  static Object _decode(List<int> body) {
    if (body.isEmpty) return <String, dynamic>{};
    return jsonDecode(utf8.decode(body));
  }

  static String _short(Object e) {
    final s = e.toString();
    return s.length > 160 ? '${s.substring(0, 157)}...' : s;
  }
}
