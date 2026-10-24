import 'package:latlong2/latlong.dart';

/// Things on the map. The first four are fixed emergency facilities; the
/// rest are live and can be added by anyone (Spec sections 6 and 33).
enum ResourceKind {
  hospital,
  pharmacy,
  police,
  fire,
  water,
  food,
  shelter,
  charging,
  transportation,
  roadProblem,
}

extension ResourceKindLayer on ResourceKind {
  /// Fixed facilities that come with the offline package.
  bool get isFacility => index <= ResourceKind.fire.index;
}

/// The kinds anyone can add from the map.
const addableResourceKinds = [
  ResourceKind.water,
  ResourceKind.food,
  ResourceKind.shelter,
  ResourceKind.charging,
  ResourceKind.transportation,
  ResourceKind.roadProblem,
];

/// What this phone's user said about a resource (Spec section 8).
enum Vote { useful, confirm, dispute }

/// Overall corroboration. Never a single "trust score" (Spec section 9).
enum Confidence { unconfirmed, low, medium, high }

/// A community member's report of what they saw, e.g. "Low".
class Observation {
  const Observation(this.text, this.at);

  final String text;
  final DateTime at;
}

class Resource {
  const Resource({
    required this.id,
    required this.kind,
    required this.name,
    required this.location,
    required this.lastObserved,
    this.organization,
    this.officialUpdate,
    this.officialStock,
    this.reserved,
    this.reservedFor,
    this.observations = const [],
    this.confirmations = 0,
    this.disputes = 0,
    this.useful = 0,
    this.myVote,
    this.approximate = true,
    this.mine = false,
    this.note = '',
  });

  final String id;
  final ResourceKind kind;
  final String name;
  final LatLng location;

  /// Set for verified organizations; null for community resources.
  final String? organization;
  final DateTime? officialUpdate;

  /// The owner's own count, e.g. 50 cases. Never reduced by subtraction
  /// on phones that may be out of sync (Spec section 29).
  final int? officialStock;

  /// How much the owner has set aside, and for which mission.
  final int? reserved;
  final String? reservedFor;

  final List<Observation> observations;
  final int confirmations;
  final int disputes;
  final int useful;
  final Vote? myVote;
  final DateTime lastObserved;

  /// Shown as roughly where it is, unless it was shared exactly.
  final bool approximate;

  /// Added from this phone.
  final bool mine;
  final String note;

  bool get verified => organization != null;

  /// One report stays visible, but ranks lower (Spec section 10).
  Confidence get confidence {
    if (verified && confirmations == 0) return Confidence.medium;
    if (confirmations == 0) return Confidence.unconfirmed;
    if (disputes * 3 >= confirmations) return Confidence.low;
    if (confirmations >= 10) return Confidence.high;
    if (confirmations >= 3) return Confidence.medium;
    return Confidence.low;
  }

  /// Old information visibly fades (Spec section 66).
  bool isStale({DateTime? now}) =>
      (now ?? DateTime.now()).difference(lastObserved) > const Duration(hours: 6);

  int? get remaining => officialStock == null
      ? null
      : (officialStock! - (reserved ?? 0)).clamp(0, officialStock!);

  /// Applies this phone's vote, replacing any earlier one.
  Resource withVote(Vote? vote) {
    int count(Vote v, int current) =>
        current - (myVote == v ? 1 : 0) + (vote == v ? 1 : 0);
    return Resource(
      id: id,
      kind: kind,
      name: name,
      location: location,
      lastObserved: vote == Vote.confirm ? DateTime.now() : lastObserved,
      organization: organization,
      officialUpdate: officialUpdate,
      officialStock: officialStock,
      reserved: reserved,
      reservedFor: reservedFor,
      observations: observations,
      confirmations: count(Vote.confirm, confirmations),
      disputes: count(Vote.dispute, disputes),
      useful: count(Vote.useful, useful),
      myVote: vote,
      approximate: approximate,
      mine: mine,
      note: note,
    );
  }
}

/// An official notice, signed by the organization that sent it.
class EmergencyAlert {
  const EmergencyAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.organization,
    required this.at,
    this.urgent = false,
  });

  final String id;
  final String title;
  final String body;
  final String organization;
  final DateTime at;
  final bool urgent;
}
