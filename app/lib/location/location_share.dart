import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';

import '../core/event_factory.dart';
import '../core/lamport_clock.dart';
import '../core/signing.dart';
import '../gen/resilience/v1/event.pb.dart';
import '../logistics/location_view.dart';
import '../messaging/secure_session.dart';

/// Identifies a single contact recipient of a location share.
///
/// The [pubkey] is the recipient's 32-byte Ed25519 public key; its lowercase
/// hex form becomes the `contact:<hex>` scope. The [session] is an established
/// 1:1 [SecureSession] toward that recipient, used to end-to-end encrypt the
/// exact point so relays never see coordinates.
class RecipientIdentity {
  RecipientIdentity({required this.pubkey, required this.session})
      : assert(pubkey.length == 32, 'recipient pubkey must be 32 bytes');

  /// The recipient's 32-byte Ed25519 public key.
  final Uint8List pubkey;

  /// The outbound Signal session toward this recipient.
  final SecureSession session;

  /// Lowercase hex of [pubkey], used to form the `contact:<hex>` scope.
  String get hex => _hex(pubkey);
}

/// Default time-box applied to a share when the caller does not pass a [ttl].
///
/// A share is NEVER indefinite: the spec requires every share to carry an
/// `expiresMs` in the future so the audience sees a countdown and the share
/// self-expires even if no explicit [LocationSharer.stop] ever arrives.
const Duration kDefaultShareTtl = Duration(minutes: 30);

/// Opt-in, audience-scoped, time-boxed, revocable location sharing.
///
/// Every method here emits a signed `LOCATION_SHARE` (or `LOCATION_STOP`)
/// event authored by the local user. The privacy contract — enforced by guards
/// in this class, not merely by convention — is:
///
///  * **contact** / **channel** scopes: the exact [GeoPoint] is serialized and
///    end-to-end encrypted to the chosen audience (Signal 1:1 for a contact,
///    Sender-Key for a channel). It travels only in `encryptedPoint`; relays
///    see opaque ciphertext. `publicPoint` MUST be empty — a guard asserts it.
///  * **public** beacon: the ONLY path where a point travels in the clear, and
///    only because the user explicitly chose a public beacon. Even then, when
///    `coarseOnly` is set the point is stripped to h3/approx via
///    [LocationView.resolve] with `hasExactAccess: false`, so `hasExact` is
///    false and no exact coordinate is present.
///
/// In all cases a coarse `h3Cell` may optionally travel in the clear only when
/// the user explicitly allowed it; it defaults to 0 (nothing coarse shared).
class LocationSharer {
  LocationSharer({
    required this.selfKeyPair,
    required this.clock,
    EventFactory? factory,
    DateTime Function()? now,
  })  : _factory = factory ?? EventFactory(),
        _now = now ?? (() => DateTime.now().toUtc());

  /// The local user's signing keypair (authors LOCATION_* events).
  final KeyPairData selfKeyPair;

  /// The local user's Lamport clock.
  final LamportClock clock;

  final EventFactory _factory;
  final DateTime Function() _now;

  int _shareCounter = 0;
  final Map<String, int> _seqByShare = <String, int>{};

  /// Share the exact [exact] point with a single [recipient].
  ///
  /// The exact point is serialized and encrypted with the recipient's 1:1
  /// [SecureSession] into `encryptedPoint`. Scope is `contact:<hex>`,
  /// `h3Cell` = [coarseH3] (or 0), `expiresMs` = now + [ttl]. `publicPoint` is
  /// left empty; a guard rejects any attempt to leak coordinates in the clear.
  Future<SignedEvent> shareWithContact(
    RecipientIdentity recipient,
    GeoPoint exact, {
    Duration ttl = kDefaultShareTtl,
    String note = '',
    int? coarseH3,
    String? shareId,
  }) async {
    final String id = shareId ?? _nextShareId();
    final Uint8List encrypted =
        await recipient.session.encrypt(_serializePoint(exact));

    final LocationShareBody body = LocationShareBody(
      shareId: id,
      scope: 'contact:${recipient.hex}',
      h3Cell: _coarse(coarseH3),
      encryptedPoint: encrypted,
      expiresMs: _expiry(ttl),
      note: note,
      seq: Int64(_nextSeq(id)),
    );
    _assertNoClearPoint(body);
    return _emitShare(body);
  }

  /// Share the exact [exact] point with a channel audience via the group's
  /// Sender-Key session [groupSession].
  ///
  /// Same privacy contract as [shareWithContact] but group-encrypted. Scope is
  /// `channel:<channelId>`.
  Future<SignedEvent> shareWithChannel(
    String channelId,
    GroupSecureSession groupSession,
    GeoPoint exact, {
    Duration ttl = kDefaultShareTtl,
    String note = '',
    int? coarseH3,
    String? shareId,
  }) async {
    final String id = shareId ?? _nextShareId();
    final Uint8List encrypted =
        await groupSession.encrypt(_serializePoint(exact));

    final LocationShareBody body = LocationShareBody(
      shareId: id,
      scope: 'channel:$channelId',
      h3Cell: _coarse(coarseH3),
      encryptedPoint: encrypted,
      expiresMs: _expiry(ttl),
      note: note,
      seq: Int64(_nextSeq(id)),
    );
    _assertNoClearPoint(body);
    return _emitShare(body);
  }

  /// Broadcast an opt-in PUBLIC beacon of [point].
  ///
  /// This is the only path where a point travels in the clear, and only because
  /// the user explicitly chose a public beacon. When [coarseOnly] (the safe
  /// default) the point is reduced to its coarse projection via
  /// [LocationView.resolve] with `hasExactAccess: false`, so the published
  /// `publicPoint` carries only `h3Cell`/approx and `hasExact` is false.
  /// `encryptedPoint` is always empty for a public beacon.
  Future<SignedEvent> broadcastPublicBeacon(
    GeoPoint point, {
    Duration ttl = kDefaultShareTtl,
    bool coarseOnly = true,
    String note = '',
    String? shareId,
  }) async {
    final String id = shareId ?? _nextShareId();

    final GeoPoint published = coarseOnly
        ? LocationView.resolve(point, hasExactAccess: false).point
        : point.deepCopy();

    // The coarse h3 that may travel in the clear mirrors whatever the published
    // point carries (0 when none).
    final Int64 h3 =
        published.hasH3Cell() ? published.h3Cell : Int64.ZERO;

    final LocationShareBody body = LocationShareBody(
      shareId: id,
      scope: 'public',
      h3Cell: h3,
      publicPoint: published,
      expiresMs: _expiry(ttl),
      note: note,
      seq: Int64(_nextSeq(id)),
    );
    _assertPublicBeacon(body, coarseOnly: coarseOnly);
    return _emitShare(body);
  }

  /// Stop (revoke) an active share. When [shareId] is null/empty this stops
  /// ALL of the author's shares. Emits a signed `LOCATION_STOP`.
  Future<SignedEvent> stop({String? shareId}) {
    final LocationStopBody body = LocationStopBody(
      shareId: shareId ?? '',
      stoppedAtMs: Int64(_now().millisecondsSinceEpoch),
    );
    return _factory.buildFromMessage(
      keyPair: selfKeyPair,
      clock: clock,
      type: EventType.EVENT_TYPE_LOCATION_STOP,
      body: body,
    );
  }

  // --- internals -------------------------------------------------------------

  Future<SignedEvent> _emitShare(LocationShareBody body) {
    return _factory.buildFromMessage(
      keyPair: selfKeyPair,
      clock: clock,
      type: EventType.EVENT_TYPE_LOCATION_SHARE,
      body: body,
      // The coarse header bucket mirrors the body's allowed coarse cell (0
      // when the user shared nothing coarse) so relay-side filters stay coarse.
      h3Cell: body.h3Cell == Int64.ZERO ? null : body.h3Cell,
    );
  }

  Int64 _coarse(int? coarseH3) =>
      (coarseH3 == null || coarseH3 == 0) ? Int64.ZERO : Int64(coarseH3);

  Int64 _expiry(Duration ttl) =>
      Int64(_now().add(ttl).millisecondsSinceEpoch);

  /// Serialize a [GeoPoint] to canonical bytes for encryption.
  static Uint8List _serializePoint(GeoPoint point) =>
      Uint8List.fromList(point.writeToBuffer());

  /// Reconstruct a [GeoPoint] from the bytes produced by [_serializePoint].
  static GeoPoint deserializePoint(List<int> bytes) =>
      GeoPoint.fromBuffer(bytes);

  String _nextShareId() {
    _shareCounter++;
    final String author =
        base64Url.encode(selfKeyPair.publicKey).substring(0, 8);
    return 'share-$author-$_shareCounter';
  }

  int _nextSeq(String shareId) {
    final int next = (_seqByShare[shareId] ?? 0) + 1;
    _seqByShare[shareId] = next;
    return next;
  }

  /// Guard: a contact/channel share must never carry a cleartext point. The
  /// precise point is only ever in `encryptedPoint`.
  static void _assertNoClearPoint(LocationShareBody body) {
    if (body.hasPublicPoint()) {
      throw StateError(
        'privacy guard: contact/channel share must not set publicPoint',
      );
    }
    if (body.encryptedPoint.isEmpty) {
      throw StateError(
        'privacy guard: contact/channel share must carry encryptedPoint',
      );
    }
    assert(!body.hasPublicPoint());
  }

  /// Guard: a public beacon must never carry encrypted contents, and a
  /// coarse-only beacon must not expose exact coordinates.
  static void _assertPublicBeacon(
    LocationShareBody body, {
    required bool coarseOnly,
  }) {
    if (body.encryptedPoint.isNotEmpty) {
      throw StateError(
        'privacy guard: public beacon must not carry encryptedPoint',
      );
    }
    if (coarseOnly) {
      final GeoPoint p = body.publicPoint;
      if (p.hasExact || p.hasExactLat() || p.hasExactLon()) {
        throw StateError(
          'privacy guard: coarse-only public beacon must not expose exact '
          'coordinates',
        );
      }
      assert(!p.hasExact);
    }
  }
}

String _hex(List<int> bytes) {
  final StringBuffer sb = StringBuffer();
  for (final int b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
