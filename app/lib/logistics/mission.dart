import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';

import '../core/event_factory.dart';
import '../core/lamport_clock.dart';
import '../core/signing.dart';
import '../gen/resilience/v1/event.pb.dart';
import 'capabilities.dart';
import 'location_view.dart';
import 'package_chain.dart';

/// Lifecycle status of a mission, folded from its events.
enum MissionStatus {
  created,
  accepted,
  matched,
  inTransit,
  awaitingHandoff,
  completed,
}

/// Operational buckets a distributor sees (spec §22).
enum MissionBucket {
  assigned,
  available,
  inTransit,
  awaitingHandoff,
  completed,
}

/// Builders for the three mission lifecycle event types.
class MissionEvents {
  MissionEvents({EventFactory? factory})
      : _factory = factory ?? EventFactory();

  final EventFactory _factory;

  /// `MISSION_CREATED`, signed by the mission creator ([creatorKeyPair]). The
  /// creator is the root authority for this mission's capability scope.
  Future<SignedEvent> created({
    required KeyPairData creatorKeyPair,
    required LamportClock clock,
    required String missionId,
    required ResourceCategory cargoCategory,
    String cargoDescription = '',
    int cargoQuantity = 0,
    String pickupName = '',
    GeoPoint? pickupLocation,
    String destinationName = '',
    GeoPoint? destinationLocation,
    Priority priority = Priority.PRIORITY_NORMAL,
    String channelId = '',
    List<int>? prevEventId,
  }) {
    final body = MissionBody(
      missionId: missionId,
      cargoCategory: cargoCategory,
      cargoDescription: cargoDescription,
      cargoQuantity: Int64(cargoQuantity),
      pickupName: pickupName,
      pickupLocation: pickupLocation,
      destinationName: destinationName,
      destinationLocation: destinationLocation,
      priority: priority,
      channelId: channelId,
    );
    return _factory.buildFromMessage(
      keyPair: creatorKeyPair,
      clock: clock,
      type: EventType.EVENT_TYPE_MISSION_CREATED,
      body: body,
      prevEventId: prevEventId,
    );
  }

  /// `MISSION_ACCEPTED`, signed by the carrier that takes the mission.
  Future<SignedEvent> accepted({
    required KeyPairData carrierKeyPair,
    required LamportClock clock,
    required String missionId,
    List<int>? prevEventId,
  }) {
    final body = MissionAcceptBody(
      missionId: missionId,
      carrierPubkey: carrierKeyPair.publicKey,
    );
    return _factory.buildFromMessage(
      keyPair: carrierKeyPair,
      clock: clock,
      type: EventType.EVENT_TYPE_MISSION_ACCEPTED,
      body: body,
      prevEventId: prevEventId,
    );
  }

  /// `MISSION_MATCHED`, signed by the coordinator ([matcherKeyPair}) that pairs
  /// a request with an offer for this mission.
  Future<SignedEvent> matched({
    required KeyPairData matcherKeyPair,
    required LamportClock clock,
    required String missionId,
    required String requestId,
    required String offerId,
    List<int>? prevEventId,
  }) {
    final body = MissionMatchBody(
      missionId: missionId,
      requestId: requestId,
      offerId: offerId,
    );
    return _factory.buildFromMessage(
      keyPair: matcherKeyPair,
      clock: clock,
      type: EventType.EVENT_TYPE_MISSION_MATCHED,
      body: body,
      prevEventId: prevEventId,
    );
  }
}

/// A folded, viewer-scoped projection of one mission.
///
/// Locations are resolved through [LocationView]: the exact pickup/destination
/// are revealed only when the viewer holds `see_exact_pickup` /
/// `see_exact_destination` for this mission's scope. All other viewers get the
/// approximate projection.
class MissionView {
  MissionView._({
    required this.missionId,
    required List<int> creator,
    required this.status,
    required this.cargoCategory,
    required this.cargoDescription,
    required this.cargoQuantity,
    required this.priority,
    required this.channelId,
    required this.pickupName,
    required this.pickup,
    required this.destinationName,
    required this.destination,
    required List<int>? carrier,
    required this.requestId,
    required this.offerId,
  })  : creator = Uint8List.fromList(creator),
        carrier = carrier == null ? null : Uint8List.fromList(carrier);

  final String missionId;
  final Uint8List creator;
  final MissionStatus status;
  final ResourceCategory cargoCategory;
  final String cargoDescription;
  final int cargoQuantity;
  final Priority priority;
  final String channelId;

  final String pickupName;

  /// Pickup location resolved for the viewer (exact or approximate).
  final LocationView pickup;

  final String destinationName;

  /// Destination location resolved for the viewer (exact or approximate).
  final LocationView destination;

  /// The carrier that accepted the mission, if any.
  final Uint8List? carrier;

  final String requestId;
  final String offerId;

  /// The capability scope string for this mission (e.g. `mission:2193`).
  String get scope => missionScope(missionId);

  /// The operational bucket for a distributor's board.
  MissionBucket get bucket {
    switch (status) {
      case MissionStatus.completed:
        return MissionBucket.completed;
      case MissionStatus.awaitingHandoff:
        return MissionBucket.awaitingHandoff;
      case MissionStatus.inTransit:
        return MissionBucket.inTransit;
      case MissionStatus.accepted:
      case MissionStatus.matched:
        return MissionBucket.assigned;
      case MissionStatus.created:
        return MissionBucket.available;
    }
  }
}

/// Projects missions out of the event log, applying capability-scoped
/// visibility and location tiers.
class MissionStore {
  MissionStore({EventFactory? factory})
      : _factory = factory ?? EventFactory();

  final EventFactory _factory;

  /// Fold every mission out of [events] visible to [viewerPubkey] given its
  /// [capabilities].
  ///
  /// Visibility rules:
  ///  * a **party** to a mission (its creator or its carrier) always sees it;
  ///  * a holder of a live capability for the mission's scope sees it;
  ///  * a holder of the distributor capability (scope [distributorScope],
  ///    action `see_all_missions`) sees every mission as operational buckets.
  ///
  /// Package events for the mission are consulted to refine status
  /// (`in_transit` once picked up, `awaiting_handoff` while a handoff is
  /// pending, `completed` on delivery).
  Future<List<MissionView>> missionsForViewer({
    required List<int> viewerPubkey,
    required CapabilitySet capabilities,
    required List<SignedEvent> events,
    String distributorScope = 'distributor',
    int? nowMs,
  }) async {
    final Uint8List viewer = Uint8List.fromList(viewerPubkey);
    final bool distributor =
        capabilities.can('see_all_missions', scope: distributorScope, nowMs: nowMs);

    // Group events by mission id.
    final Map<String, _MissionAgg> byMission = <String, _MissionAgg>{};

    // Deterministic order.
    final List<SignedEvent> ordered = List<SignedEvent>.of(events)
      ..sort(_compareEvents);

    for (final SignedEvent e in ordered) {
      if (!await _factory.verifyEvent(e)) continue;
      switch (e.header.type) {
        case EventType.EVENT_TYPE_MISSION_CREATED:
          final MissionBody b = MissionBody.fromBuffer(e.body);
          (byMission[b.missionId] ??= _MissionAgg(b.missionId))
            ..created = b
            ..creator = Uint8List.fromList(e.header.authorPubkey);
          break;
        case EventType.EVENT_TYPE_MISSION_ACCEPTED:
          final MissionAcceptBody b = MissionAcceptBody.fromBuffer(e.body);
          (byMission[b.missionId] ??= _MissionAgg(b.missionId)).carrier =
              Uint8List.fromList(b.carrierPubkey);
          break;
        case EventType.EVENT_TYPE_MISSION_MATCHED:
          final MissionMatchBody b = MissionMatchBody.fromBuffer(e.body);
          (byMission[b.missionId] ??= _MissionAgg(b.missionId))
            ..requestId = b.requestId
            ..offerId = b.offerId;
          break;
        case EventType.EVENT_TYPE_PACKAGE_PICKED_UP:
        case EventType.EVENT_TYPE_PACKAGE_TRANSFERRED:
        case EventType.EVENT_TYPE_DELIVERY_COMPLETED:
          final PackageEventBody b = PackageEventBody.fromBuffer(e.body);
          (byMission[b.missionId] ??= _MissionAgg(b.missionId))
              .packageEvents
              .add(e);
          break;
        default:
          break;
      }
    }

    final List<MissionView> out = <MissionView>[];
    for (final _MissionAgg agg in byMission.values) {
      final MissionBody? m = agg.created;
      if (m == null) continue; // no creation event -> skip

      final bool isParty = _bytesEqual(agg.creator ?? const <int>[], viewer) ||
          (agg.carrier != null && _bytesEqual(agg.carrier!, viewer));
      final bool hasScope =
          capabilities.hasScope(missionScope(agg.missionId), nowMs: nowMs);

      if (!isParty && !hasScope && !distributor) continue;

      final bool exactPickup = isParty ||
          capabilities.can('see_exact_pickup',
              scope: missionScope(agg.missionId), nowMs: nowMs);
      final bool exactDest = isParty ||
          capabilities.can('see_exact_destination',
              scope: missionScope(agg.missionId), nowMs: nowMs);

      final MissionStatus status = await _statusFor(agg);

      out.add(MissionView._(
        missionId: agg.missionId,
        creator: agg.creator ?? const <int>[],
        status: status,
        cargoCategory: m.cargoCategory,
        cargoDescription: m.cargoDescription,
        cargoQuantity: m.cargoQuantity.toInt(),
        priority: m.priority,
        channelId: m.channelId,
        pickupName: m.pickupName,
        pickup: LocationView.resolve(
          m.hasPickupLocation() ? m.pickupLocation : GeoPoint(),
          hasExactAccess: exactPickup,
        ),
        destinationName: m.destinationName,
        destination: LocationView.resolve(
          m.hasDestinationLocation() ? m.destinationLocation : GeoPoint(),
          hasExactAccess: exactDest,
        ),
        carrier: agg.carrier,
        requestId: agg.requestId,
        offerId: agg.offerId,
      ));
    }

    out.sort((a, b) => a.missionId.compareTo(b.missionId));
    return out;
  }

  Future<MissionStatus> _statusFor(_MissionAgg agg) async {
    if (agg.packageEvents.isNotEmpty) {
      final PackageChain chain = await PackageChain.fromEvents(
        packageId: agg.missionId,
        events: agg.packageEvents,
        factory: _factory,
      );
      if (chain.delivered) return MissionStatus.completed;
      // A transfer present but not yet a clean confirmed chain => awaiting.
      final bool anyTransfer = agg.packageEvents.any((e) =>
          e.header.type == EventType.EVENT_TYPE_PACKAGE_TRANSFERRED);
      if (anyTransfer && !chain.isValid) {
        return MissionStatus.awaitingHandoff;
      }
      return MissionStatus.inTransit;
    }
    if (agg.carrier != null) return MissionStatus.accepted;
    if (agg.requestId.isNotEmpty || agg.offerId.isNotEmpty) {
      return MissionStatus.matched;
    }
    return MissionStatus.created;
  }

  static int _compareEvents(SignedEvent a, SignedEvent b) {
    final int la = a.header.lamport.toInt();
    final int lb = b.header.lamport.toInt();
    if (la != lb) return la - lb;
    return _compareBytes(a.header.eventId, b.header.eventId);
  }
}

class _MissionAgg {
  _MissionAgg(this.missionId);
  final String missionId;
  MissionBody? created;
  Uint8List? creator;
  Uint8List? carrier;
  String requestId = '';
  String offerId = '';
  final List<SignedEvent> packageEvents = <SignedEvent>[];
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
