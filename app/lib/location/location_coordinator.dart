import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

import '../core/event_store.dart';
import '../gen/resilience/v1/event.pb.dart';
import '../messaging/messaging_service.dart';
import 'location_share.dart';
import 'position_service.dart';

/// Precision the user chose for a share.
enum SharePrecision {
  /// Exact coordinates (sub-meter), only when the user explicitly opts in.
  exact,

  /// Rounded to ~110 m (3 decimals) — the privacy-preserving default.
  approximate,
}

/// The outcome of attempting to start a location share.
class ShareResult {
  const ShareResult._({
    this.shareId,
    this.failure,
    this.unreachable = const <String>[],
    this.delivered = 0,
  });

  /// A share succeeded (at least one recipient reached, or a public beacon).
  const ShareResult.ok({
    required String shareId,
    int delivered = 0,
    List<String> unreachable = const <String>[],
  }) : this._(
          shareId: shareId,
          delivered: delivered,
          unreachable: unreachable,
        );

  /// Reading the device position failed — the UI shows an honest message.
  const ShareResult.positionFailed(PositionFailure failure)
      : this._(failure: failure);

  /// No recipient could be reached (no contact has published a prekey bundle),
  /// so nothing was shared.
  const ShareResult.noRecipients({List<String> unreachable = const <String>[]})
      : this._(unreachable: unreachable);

  /// The share id when at least one recipient was reached, else null.
  final String? shareId;

  /// The position failure when reading the one-shot position failed, else null.
  final PositionFailure? failure;

  /// Recipient hexes that had no session/bundle and were skipped.
  final List<String> unreachable;

  /// How many contacts actually received an encrypted share.
  final int delivered;

  bool get succeeded => shareId != null;
}

/// Coordinates opt-in location sharing end to end: it reads a one-shot position,
/// encrypts the precise point to each chosen contact over the SAME durable
/// Signal sessions used for messaging (FEAT-003), emits signed `LOCATION_SHARE`
/// / `LOCATION_STOP` events through the [EventStore], and asks the caller to
/// trigger a sync so the events reach peers.
///
/// Privacy contract (enforced by [LocationSharer] guards, not convention):
///  * contact scope -> precise point ONLY in `encryptedPoint` ciphertext;
///  * the point is rounded to ~110 m unless the user picked [SharePrecision.exact];
///  * nothing here logs a coordinate.
class LocationCoordinator {
  LocationCoordinator({
    required this.sharer,
    required this.messaging,
    required this.store,
    Future<PositionResult> Function()? readPosition,
  }) : _readPosition = readPosition ?? readPositionOneShot;

  final LocationSharer sharer;
  final MessagingService messaging;
  final EventStore store;
  final Future<PositionResult> Function() _readPosition;

  /// Reads a one-shot device position through the SAME injectable seam the
  /// contact-share path uses. Callers (e.g. the public-beacon UI path) must go
  /// through this rather than the top-level `readPosition()` so their behavior
  /// is driveable by the same test stub as [shareWithContacts].
  Future<PositionResult> readPosition() => _readPosition();

  /// Share the local user's position with each contact in [contacts] (their
  /// 32-byte Ed25519 pubkeys) for [ttl]. The precise point is encrypted
  /// per-recipient; a recipient with no established session (no published
  /// prekey bundle) is reported in [ShareResult.unreachable] and skipped.
  ///
  /// All encrypted shares use the SAME [shareId] so a single `LOCATION_STOP`
  /// (by id) revokes them all at once.
  Future<ShareResult> shareWithContacts({
    required List<List<int>> contacts,
    required SharePrecision precision,
    required Duration ttl,
    String note = '',
    String? shareId,
  }) async {
    if (contacts.isEmpty) {
      return const ShareResult.noRecipients();
    }

    final PositionResult pos = await _readPosition();
    final LatLng? at = pos.position;
    if (at == null) {
      return ShareResult.positionFailed(
          pos.failure ?? PositionFailure.unknown);
    }

    final GeoPoint point =
        geoPointFor(at, exact: precision == SharePrecision.exact);
    final String id = shareId ?? _newShareId();

    final List<String> unreachable = <String>[];
    int delivered = 0;
    for (final List<int> pubkey in contacts) {
      final session = await messaging.outboundSessionFor(pubkey);
      if (session == null) {
        unreachable.add(_hex(pubkey));
        continue;
      }
      final SignedEvent ev = await sharer.shareWithContact(
        RecipientIdentity(pubkey: _as32(pubkey), session: session),
        point,
        ttl: ttl,
        note: note,
        shareId: id,
      );
      await store.apply(ev);
      delivered++;
    }

    if (delivered == 0) {
      return ShareResult.noRecipients(unreachable: unreachable);
    }
    return ShareResult.ok(
      shareId: id,
      delivered: delivered,
      unreachable: unreachable,
    );
  }

  /// Stop one share (by [shareId]) or ALL of the local user's shares (null /
  /// empty [shareId]). Emits a signed `LOCATION_STOP`.
  Future<void> stop({String? shareId}) async {
    final SignedEvent ev = await sharer.stop(shareId: shareId);
    await store.apply(ev);
  }

  String _newShareId() =>
      'loc-${DateTime.now().toUtc().millisecondsSinceEpoch}';

  static Uint8List _as32(List<int> b) => Uint8List.fromList(
      b.length == 32 ? b : (b.length > 32 ? b.sublist(0, 32) : b));

  static String _hex(List<int> bytes) {
    final StringBuffer sb = StringBuffer();
    for (final int b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}

/// A one-shot position read, named so it can be stubbed in tests.
Future<PositionResult> readPositionOneShot() => readPosition();
