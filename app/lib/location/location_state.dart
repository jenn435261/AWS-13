import 'dart:typed_data';

import '../gen/resilience/v1/event.pb.dart';
import '../messaging/secure_session.dart';
import 'location_share.dart';

/// A viewer's decryption material for folding incoming shares.
///
/// Provide:
///  * [viewerPubkey] — the local user's 32-byte Ed25519 public key. Used to
///    recognize `contact:<hex>` shares addressed to this viewer.
///  * [contactSessions] — inbound 1:1 [SecureSession]s keyed by the SHARER's
///    pubkey hex (lowercase). Used to decrypt a contact share's
///    `encryptedPoint`.
///  * [channelSessions] — [GroupSecureSession]s keyed by channel id, for
///    channels this viewer belongs to.
///  * [senderNameOf] — maps a sharer's author pubkey to the group sender name
///    used in the Sender-Key session (defaults to the lowercase hex of the
///    pubkey).
class ShareSessions {
  ShareSessions({
    required this.viewerPubkey,
    Map<String, SecureSession>? contactSessions,
    Map<String, GroupSecureSession>? channelSessions,
    String Function(List<int> authorPubkey)? senderNameOf,
  })  : contactSessions = contactSessions ?? <String, SecureSession>{},
        channelSessions = channelSessions ?? <String, GroupSecureSession>{},
        senderNameOf = senderNameOf ?? _defaultSenderName;

  /// The local viewer's 32-byte Ed25519 public key.
  final Uint8List viewerPubkey;

  /// Inbound 1:1 sessions keyed by the SHARER's pubkey hex.
  final Map<String, SecureSession> contactSessions;

  /// Group sessions keyed by channel id.
  final Map<String, GroupSecureSession> channelSessions;

  /// Maps a sharer's author pubkey to its group sender name.
  final String Function(List<int> authorPubkey) senderNameOf;

  /// Lowercase hex of the viewer's pubkey.
  String get viewerHex => _hex(viewerPubkey);

  static String _defaultSenderName(List<int> authorPubkey) =>
      _hex(authorPubkey);
}

/// An outgoing share authored by the local user, with a live countdown.
class OutgoingShare {
  OutgoingShare({
    required this.shareId,
    required this.scope,
    required this.expiresMs,
    required this.note,
    required this.seq,
    required Duration remaining,
  }) : remaining = remaining.isNegative ? Duration.zero : remaining;

  final String shareId;
  final String scope;
  final int expiresMs;
  final String note;
  final int seq;

  /// Time left until this share self-expires (never negative).
  final Duration remaining;
}

/// An incoming share addressed to the viewer (directly or via a channel),
/// resolved to a usable [GeoPoint] + note + freshness.
class IncomingShare {
  IncomingShare({
    required this.shareId,
    required this.scope,
    required this.sharerPubkey,
    required this.point,
    required this.note,
    required this.expiresMs,
    required this.seq,
    required Duration freshness,
  }) : freshness = freshness.isNegative ? Duration.zero : freshness;

  final String shareId;
  final String scope;

  /// The author (sharer) pubkey.
  final Uint8List sharerPubkey;

  /// The resolved location: the decrypted exact point for contact/channel
  /// shares, or the coarse `publicPoint` for a public beacon.
  final GeoPoint point;
  final String note;
  final int expiresMs;
  final int seq;

  /// Time left until this share expires (never negative).
  final Duration freshness;
}

/// Folds `LOCATION_SHARE` / `LOCATION_STOP` events into the current set of
/// active shares.
///
/// Derivation rules (pure function of the event log):
///  * The latest `LOCATION_SHARE` per `shareId` (highest `seq`, then highest
///    lamport) wins.
///  * A `LOCATION_STOP` with a matching `shareId` removes that share. A
///    `LOCATION_STOP` with an EMPTY `shareId` stops ALL shares by that author.
///  * A share whose `expiresMs` is at/behind "now" is excluded (self-expiry).
///
/// [outgoing] lists the local user's own still-active shares with a countdown.
/// [incomingFor] decrypts shares addressed to the viewer (a `contact:<hex>`
/// matching the viewer, or a `channel:<id>` the viewer belongs to) and returns
/// only those that could be resolved.
class ActiveShares {
  ActiveShares._(this._shares, this._stops, this._now);

  /// The latest share body per (author, shareId).
  final Map<String, _ShareRecord> _shares;

  /// Per-author stop state folded from `LOCATION_STOP` events.
  final Map<String, _StopState> _stops;

  final DateTime Function() _now;

  /// Fold [events] (across sharers and relays) into the active-share view.
  ///
  /// [now] supplies the clock for expiry/countdown (defaults to UTC now).
  static ActiveShares fold(
    Iterable<SignedEvent> events, {
    DateTime Function()? now,
  }) {
    final DateTime Function() clock = now ?? (() => DateTime.now().toUtc());
    final Map<String, _ShareRecord> shares = <String, _ShareRecord>{};
    final Map<String, _StopState> stops = <String, _StopState>{};

    for (final SignedEvent ev in events) {
      final EventType t = ev.header.type;
      if (t == EventType.EVENT_TYPE_LOCATION_SHARE) {
        final LocationShareBody body = LocationShareBody.fromBuffer(ev.body);
        final String author = _hex(ev.header.authorPubkey);
        final String key = '$author/${body.shareId}';
        final int seq = body.seq.toInt();
        final int lamport = ev.header.lamport.toInt();
        final _ShareRecord? existing = shares[key];
        if (existing == null ||
            seq > existing.seq ||
            (seq == existing.seq && lamport > existing.lamport)) {
          shares[key] = _ShareRecord(
            author: Uint8List.fromList(ev.header.authorPubkey),
            body: body,
            seq: seq,
            lamport: lamport,
          );
        }
      } else if (t == EventType.EVENT_TYPE_LOCATION_STOP) {
        final LocationStopBody body = LocationStopBody.fromBuffer(ev.body);
        final String author = _hex(ev.header.authorPubkey);
        final _StopState state =
            stops.putIfAbsent(author, () => _StopState());
        if (body.shareId.isEmpty) {
          state.stopAll = true;
        } else {
          state.stoppedIds.add(body.shareId);
        }
      }
    }
    return ActiveShares._(shares, stops, clock);
  }

  bool _isStopped(String author, String shareId) {
    final _StopState? state = _stops[author];
    if (state == null) return false;
    return state.stopAll || state.stoppedIds.contains(shareId);
  }

  bool _isExpired(int expiresMs, int nowMs) => expiresMs <= nowMs;

  /// Active shares NOT authored by [viewerPubkey] (i.e. candidates for others
  /// to view), used internally; see [outgoing] / [incomingFor] for the public
  /// API.
  Iterable<_ShareRecord> _activeRecords(int nowMs) sync* {
    for (final _ShareRecord rec in _shares.values) {
      final String author = _hex(rec.author);
      if (_isStopped(author, rec.body.shareId)) continue;
      if (_isExpired(rec.body.expiresMs.toInt(), nowMs)) continue;
      yield rec;
    }
  }

  /// The local user's own active (non-expired, non-stopped) outgoing shares,
  /// newest-sequence first, each carrying a live countdown.
  List<OutgoingShare> outgoing() {
    final int nowMs = _now().millisecondsSinceEpoch;
    final List<OutgoingShare> out = <OutgoingShare>[];
    for (final _ShareRecord rec in _activeRecords(nowMs)) {
      final int expiresMs = rec.body.expiresMs.toInt();
      out.add(OutgoingShare(
        shareId: rec.body.shareId,
        scope: rec.body.scope,
        expiresMs: expiresMs,
        note: rec.body.note,
        seq: rec.seq,
        remaining: Duration(milliseconds: expiresMs - nowMs),
      ));
    }
    out.sort((a, b) => b.seq.compareTo(a.seq));
    return out;
  }

  /// Incoming active shares addressed to the viewer in [sessions], decrypted
  /// (via the matching 1:1 or group session) to a resolved [GeoPoint].
  ///
  /// Only shares the viewer is actually the audience for are returned:
  ///  * `contact:<hex>` where `<hex>` equals the viewer's pubkey hex;
  ///  * `channel:<id>` where the viewer holds a session for `<id>`;
  ///  * `public` beacons (coarse point already in the clear).
  ///
  /// A share whose ciphertext cannot be decrypted with the available session
  /// is skipped (never surfaced in cleartext-less form).
  Future<List<IncomingShare>> incomingFor(ShareSessions sessions) async {
    final int nowMs = _now().millisecondsSinceEpoch;
    final List<IncomingShare> out = <IncomingShare>[];

    for (final _ShareRecord rec in _activeRecords(nowMs)) {
      final LocationShareBody body = rec.body;
      final String scope = body.scope;
      final GeoPoint? resolved = await _resolveForViewer(rec, sessions);
      if (resolved == null) continue;

      final int expiresMs = body.expiresMs.toInt();
      out.add(IncomingShare(
        shareId: body.shareId,
        scope: scope,
        sharerPubkey: Uint8List.fromList(rec.author),
        point: resolved,
        note: body.note,
        expiresMs: expiresMs,
        seq: rec.seq,
        freshness: Duration(milliseconds: expiresMs - nowMs),
      ));
    }
    out.sort((a, b) => b.seq.compareTo(a.seq));
    return out;
  }

  Future<GeoPoint?> _resolveForViewer(
    _ShareRecord rec,
    ShareSessions sessions,
  ) async {
    final LocationShareBody body = rec.body;
    final String scope = body.scope;

    if (scope == 'public') {
      if (!body.hasPublicPoint()) return null;
      return body.publicPoint;
    }

    if (scope.startsWith('contact:')) {
      final String target = scope.substring('contact:'.length);
      if (target != sessions.viewerHex) return null;
      final String sharerHex = _hex(rec.author);
      final SecureSession? session = sessions.contactSessions[sharerHex];
      if (session == null || body.encryptedPoint.isEmpty) return null;
      return _tryDecrypt(() => session.decrypt(
            Uint8List.fromList(body.encryptedPoint),
          ));
    }

    if (scope.startsWith('channel:')) {
      final String channelId = scope.substring('channel:'.length);
      final GroupSecureSession? group = sessions.channelSessions[channelId];
      if (group == null || body.encryptedPoint.isEmpty) return null;
      final String senderName = sessions.senderNameOf(rec.author);
      return _tryDecrypt(() => group.decrypt(
            senderName: senderName,
            ciphertext: Uint8List.fromList(body.encryptedPoint),
          ));
    }

    return null;
  }

  Future<GeoPoint?> _tryDecrypt(
    Future<Uint8List> Function() decrypt,
  ) async {
    try {
      final Uint8List plain = await decrypt();
      return LocationSharer.deserializePoint(plain);
    } catch (_) {
      return null;
    }
  }
}

class _ShareRecord {
  _ShareRecord({
    required this.author,
    required this.body,
    required this.seq,
    required this.lamport,
  });

  final Uint8List author;
  final LocationShareBody body;
  final int seq;
  final int lamport;
}

class _StopState {
  bool stopAll = false;
  final Set<String> stoppedIds = <String>{};
}

String _hex(List<int> bytes) {
  final StringBuffer sb = StringBuffer();
  for (final int b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
