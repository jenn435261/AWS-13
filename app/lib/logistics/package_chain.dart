import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';

import '../core/event_factory.dart';
import '../core/lamport_clock.dart';
import '../core/signing.dart';
import '../gen/resilience/v1/event.pb.dart';

/// QR-driven, cryptographically-signed package custody chain (spec §24-27).
///
/// Each physical hand of custody is a signed [PackageEventBody] event:
///
///  * **PICKUP** — the pickup site scans the driver's mission QR and the driver
///    scans the package QR, producing a `PACKAGE_PICKED_UP` event
///    (`STAGE_PICKED_UP`) signed by the driver (actor) with the source as
///    counterparty.
///  * **HANDOFF A -> B** — driver A signs "I transferred `pkg`"
///    (`PACKAGE_TRANSFERRED`, `STAGE_TRANSFERRED`, actor=A, counterparty=B) and
///    driver B signs "I received `pkg`" (`PACKAGE_TRANSFERRED`,
///    `STAGE_TRANSFERRED`, actor=B, counterparty=A). The handoff is **confirmed**
///    only when BOTH the transfer and the matching receive are present.
///  * **DELIVERY** — the recipient scans, producing `DELIVERY_COMPLETED`
///    (`STAGE_DELIVERED`).
///
/// The full chain (Source -> Driver A -> Driver B -> Shelter) is reconstructable
/// and verifiable from the events alone: [PackageChain.fromEvents] verifies
/// every signature, orders the steps, checks custody continuity, and exposes
/// the audit trail. A missing or forged link makes [PackageChain.isValid]
/// false.

/// One confirmed hop in the audit trail.
class CustodyHop {
  CustodyHop({
    required this.stage,
    required List<int> actor,
    required List<int> counterparty,
    required this.atMs,
  })  : actor = Uint8List.fromList(actor),
        counterparty = Uint8List.fromList(counterparty);

  final PackageEventBody_Stage stage;
  final Uint8List actor;
  final Uint8List counterparty;
  final int atMs;

  @override
  String toString() =>
      'CustodyHop($stage actor=${_hex(actor)} '
      'counterparty=${_hex(counterparty)} atMs=$atMs)';
}

/// Builders for the three package lifecycle event types.
class PackageEvents {
  PackageEvents({EventFactory? factory})
      : _factory = factory ?? EventFactory();

  final EventFactory _factory;

  /// `PACKAGE_PICKED_UP`, signed by [actorKeyPair] (the driver). [counterparty]
  /// is the pickup site's pubkey.
  Future<SignedEvent> pickedUp({
    required KeyPairData actorKeyPair,
    required LamportClock clock,
    required String packageId,
    required String missionId,
    required List<int> counterparty,
    int? atMs,
    List<int>? prevEventId,
  }) {
    return _build(
      actorKeyPair: actorKeyPair,
      clock: clock,
      type: EventType.EVENT_TYPE_PACKAGE_PICKED_UP,
      stage: PackageEventBody_Stage.STAGE_PICKED_UP,
      packageId: packageId,
      missionId: missionId,
      counterparty: counterparty,
      atMs: atMs,
      prevEventId: prevEventId,
    );
  }

  /// `PACKAGE_TRANSFERRED`, signed by [actorKeyPair]. Used for BOTH sides of a
  /// handoff: the *transferring* driver (actor=from, counterparty=to) and the
  /// *receiving* driver (actor=to, counterparty=from).
  Future<SignedEvent> transferred({
    required KeyPairData actorKeyPair,
    required LamportClock clock,
    required String packageId,
    required String missionId,
    required List<int> counterparty,
    int? atMs,
    List<int>? prevEventId,
  }) {
    return _build(
      actorKeyPair: actorKeyPair,
      clock: clock,
      type: EventType.EVENT_TYPE_PACKAGE_TRANSFERRED,
      stage: PackageEventBody_Stage.STAGE_TRANSFERRED,
      packageId: packageId,
      missionId: missionId,
      counterparty: counterparty,
      atMs: atMs,
      prevEventId: prevEventId,
    );
  }

  /// `DELIVERY_COMPLETED`, signed by [actorKeyPair] (the recipient).
  Future<SignedEvent> delivered({
    required KeyPairData actorKeyPair,
    required LamportClock clock,
    required String packageId,
    required String missionId,
    required List<int> counterparty,
    int? atMs,
    List<int>? prevEventId,
  }) {
    return _build(
      actorKeyPair: actorKeyPair,
      clock: clock,
      type: EventType.EVENT_TYPE_DELIVERY_COMPLETED,
      stage: PackageEventBody_Stage.STAGE_DELIVERED,
      packageId: packageId,
      missionId: missionId,
      counterparty: counterparty,
      atMs: atMs,
      prevEventId: prevEventId,
    );
  }

  Future<SignedEvent> _build({
    required KeyPairData actorKeyPair,
    required LamportClock clock,
    required EventType type,
    required PackageEventBody_Stage stage,
    required String packageId,
    required String missionId,
    required List<int> counterparty,
    int? atMs,
    List<int>? prevEventId,
  }) {
    final int ts = atMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final body = PackageEventBody(
      packageId: packageId,
      missionId: missionId,
      actorPubkey: actorKeyPair.publicKey,
      counterpartyPubkey: counterparty,
      stage: stage,
      atMs: Int64(ts),
    );
    return _factory.buildFromMessage(
      keyPair: actorKeyPair,
      clock: clock,
      type: type,
      body: body,
      prevEventId: prevEventId,
    );
  }
}

/// A reconstructed, validated custody chain for a single package.
class PackageChain {
  PackageChain._({
    required this.packageId,
    required this.hops,
    required this.isValid,
    required this.invalidReason,
    required this.handoffsConfirmed,
    required this.delivered,
  });

  final String packageId;

  /// The ordered audit trail: pickup, each confirmed handoff, delivery.
  final List<CustodyHop> hops;

  /// Whether the whole chain validates: every event signed correctly by its
  /// actor, a leading pickup, contiguous custody across handoffs (the receiver
  /// of one hop is the transferrer of the next), both sides present for each
  /// handoff, and (if ended) a delivery by the final custodian.
  final bool isValid;

  /// Human-readable reason [isValid] is false, or `null` when valid.
  final String? invalidReason;

  /// Count of fully-confirmed handoffs (transfer + matching receive).
  final int handoffsConfirmed;

  /// Whether the chain terminates in a `DELIVERY_COMPLETED`.
  final bool delivered;

  /// Reconstruct and validate the chain for [packageId] from [events].
  ///
  /// [events] may contain unrelated events; only package events for
  /// [packageId] are considered. Every considered event is signature-verified
  /// via [factory]; a forged signature fails the chain.
  static Future<PackageChain> fromEvents({
    required String packageId,
    required List<SignedEvent> events,
    EventFactory? factory,
  }) async {
    final EventFactory f = factory ?? EventFactory();

    // Collect & verify this package's events.
    final List<_PkgEvent> pkg = <_PkgEvent>[];
    for (final SignedEvent e in events) {
      final EventType t = e.header.type;
      final bool relevant = t == EventType.EVENT_TYPE_PACKAGE_PICKED_UP ||
          t == EventType.EVENT_TYPE_PACKAGE_TRANSFERRED ||
          t == EventType.EVENT_TYPE_DELIVERY_COMPLETED;
      if (!relevant) continue;

      final PackageEventBody body = PackageEventBody.fromBuffer(e.body);
      if (body.packageId != packageId) continue;

      if (!await f.verifyEvent(e)) {
        return PackageChain._(
          packageId: packageId,
          hops: const <CustodyHop>[],
          isValid: false,
          invalidReason: 'forged or malformed signature in chain',
          handoffsConfirmed: 0,
          delivered: false,
        );
      }

      // The event author MUST be the body's declared actor (you cannot sign a
      // custody step on someone else's behalf).
      if (!_bytesEqual(e.header.authorPubkey, body.actorPubkey)) {
        return PackageChain._(
          packageId: packageId,
          hops: const <CustodyHop>[],
          isValid: false,
          invalidReason: 'actor/author mismatch in chain',
          handoffsConfirmed: 0,
          delivered: false,
        );
      }

      pkg.add(_PkgEvent(e, body));
    }

    if (pkg.isEmpty) {
      return PackageChain._(
        packageId: packageId,
        hops: const <CustodyHop>[],
        isValid: false,
        invalidReason: 'no package events',
        handoffsConfirmed: 0,
        delivered: false,
      );
    }

    // Deterministic order: by atMs, then lamport, then event id.
    pkg.sort(_comparePkg);

    final List<_PkgEvent> pickups = pkg
        .where((p) => p.body.stage == PackageEventBody_Stage.STAGE_PICKED_UP)
        .toList();
    final List<_PkgEvent> transfers = pkg
        .where((p) => p.body.stage == PackageEventBody_Stage.STAGE_TRANSFERRED)
        .toList();
    final List<_PkgEvent> deliveries = pkg
        .where((p) => p.body.stage == PackageEventBody_Stage.STAGE_DELIVERED)
        .toList();

    if (pickups.isEmpty) {
      return _invalid(packageId, 'missing pickup (first custody link)');
    }

    final List<CustodyHop> hops = <CustodyHop>[];

    // 1) Pickup: establishes the first custodian (the actor/driver).
    final _PkgEvent pickup = pickups.first;
    hops.add(_hop(pickup));
    Uint8List custodian = Uint8List.fromList(pickup.body.actorPubkey);

    // 2) Handoffs: pair each TRANSFER (actor=current custodian) with a matching
    //    RECEIVE (actor=counterparty). Both must be present => confirmed.
    int confirmed = 0;

    // Group transfer events by the (from,to) unordered pair for matching.
    // A handoff is current-custodian -> next, confirmed when we also have the
    // reverse-perspective transfer (actor=next, counterparty=current).
    bool progressed = true;
    final Set<int> used = <int>{};
    while (progressed) {
      progressed = false;
      for (int i = 0; i < transfers.length; i++) {
        if (used.contains(i)) continue;
        final _PkgEvent out = transfers[i];
        // The transferring side: actor is the current custodian.
        if (!_bytesEqual(out.body.actorPubkey, custodian)) continue;
        final Uint8List next =
            Uint8List.fromList(out.body.counterpartyPubkey);

        // Find the matching receive side: actor=next, counterparty=custodian.
        int matchIdx = -1;
        for (int j = 0; j < transfers.length; j++) {
          if (j == i || used.contains(j)) continue;
          final _PkgEvent rec = transfers[j];
          if (_bytesEqual(rec.body.actorPubkey, next) &&
              _bytesEqual(rec.body.counterpartyPubkey, custodian)) {
            matchIdx = j;
            break;
          }
        }
        if (matchIdx == -1) {
          return _invalid(
            packageId,
            'unconfirmed handoff: transfer without matching receive',
          );
        }
        used.add(i);
        used.add(matchIdx);
        confirmed++;
        hops.add(_hop(out));
        custodian = next;
        progressed = true;
        break;
      }
    }

    // Any transfer events left unmatched => a broken/forged link.
    if (used.length != transfers.length) {
      return _invalid(
        packageId,
        'dangling transfer event not connected to custody chain',
      );
    }

    // 3) Delivery (optional terminal step): must be signed by the final
    //    custodian.
    bool delivered = false;
    if (deliveries.isNotEmpty) {
      final _PkgEvent del = deliveries.first;
      if (!_bytesEqual(del.body.actorPubkey, custodian)) {
        return _invalid(
          packageId,
          'delivery not signed by the final custodian',
        );
      }
      hops.add(_hop(del));
      delivered = true;
    }

    return PackageChain._(
      packageId: packageId,
      hops: List<CustodyHop>.unmodifiable(hops),
      isValid: true,
      invalidReason: null,
      handoffsConfirmed: confirmed,
      delivered: delivered,
    );
  }

  static PackageChain _invalid(String packageId, String reason) => PackageChain._(
        packageId: packageId,
        hops: const <CustodyHop>[],
        isValid: false,
        invalidReason: reason,
        handoffsConfirmed: 0,
        delivered: false,
      );

  static CustodyHop _hop(_PkgEvent p) => CustodyHop(
        stage: p.body.stage,
        actor: p.body.actorPubkey,
        counterparty: p.body.counterpartyPubkey,
        atMs: p.body.atMs.toInt(),
      );

  static int _comparePkg(_PkgEvent a, _PkgEvent b) {
    final int ta = a.body.atMs.toInt();
    final int tb = b.body.atMs.toInt();
    if (ta != tb) return ta - tb;
    final int la = a.event.header.lamport.toInt();
    final int lb = b.event.header.lamport.toInt();
    if (la != lb) return la - lb;
    return _compareBytes(a.event.header.eventId, b.event.header.eventId);
  }
}

class _PkgEvent {
  _PkgEvent(this.event, this.body);
  final SignedEvent event;
  final PackageEventBody body;
}

String _hex(List<int> bytes) {
  final StringBuffer sb = StringBuffer();
  for (final int b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _compareBytes(List<int> a, List<int> b) {
  final int n = a.length < b.length ? a.length : b.length;
  for (int i = 0; i < n; i++) {
    final int d = a[i] - b[i];
    if (d != 0) return d;
  }
  return a.length - b.length;
}
