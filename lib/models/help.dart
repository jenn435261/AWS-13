import 'package:latlong2/latlong.dart';

/// What someone needs (Spec section 4). Fixed choices travel as a few bytes
/// over the weakest networks, and every language can show them offline.
enum HelpKind {
  water,
  food,
  medicine,
  shelter,
  power,
  transportation,
  medical,
  communication,
  other,
}

enum Urgency { now, soon, later }

/// Supplies someone can offer (Spec section 5).
enum SupplyKind {
  water,
  food,
  blankets,
  batteries,
  charging,
  medicine,
  transportation,
  shelter,
  tools,
  other,
}

enum Amount { plenty, some, low }

enum Availability { now, today, custom }

/// How a volunteer can move things (Spec section 21).
enum TransportMode { walking, bicycle, car, truck, van }

enum Capacity { small, medium, large }

/// A request's trip to a helper. Only the phone sets [saved]; everything
/// after that is reported back by the network.
enum RequestStage { saved, mesh, verified, assigned, onTheWay, resolved }

class HelpRequest {
  const HelpRequest({
    required this.id,
    required this.kind,
    required this.urgency,
    required this.people,
    required this.createdAt,
    required this.senderName,
    this.location,
    this.locationNote = '',
    this.note = '',
    this.mine = false,
    this.sos = false,
    this.stage = RequestStage.saved,
    this.stageTimes = const {},
    this.hops = 0,
    this.helperName,
    this.helpingIsMe = false,
  });

  final String id;
  final HelpKind kind;
  final Urgency urgency;
  final int people;
  final DateTime createdAt;
  final String senderName;

  /// Null when the phone has no location fix; [locationNote] then says where.
  final LatLng? location;
  final String locationNote;

  /// Free text. Sent after the fixed choices, when the network has room.
  final String note;

  /// Sent from this phone.
  final bool mine;

  /// Sent with the hold-for-SOS button, skipping the questions.
  final bool sos;

  final RequestStage stage;
  final Map<RequestStage, DateTime> stageTimes;

  /// Radios the request passed through on the mesh.
  final int hops;
  final String? helperName;

  /// This phone's user accepted someone else's request.
  final bool helpingIsMe;

  bool get isOpen => stage.index < RequestStage.assigned.index;

  HelpRequest advance(RequestStage next, {int? hops, String? helperName}) =>
      _copy(
        stage: next,
        stageTimes: {...stageTimes, next: DateTime.now()},
        hops: hops,
        helperName: helperName,
      );

  HelpRequest acceptedByMe(String name) => _copy(
        stage: RequestStage.assigned,
        stageTimes: {...stageTimes, RequestStage.assigned: DateTime.now()},
        helperName: name,
        helpingIsMe: true,
      );

  /// Undoes [acceptedByMe]: back to waiting for a helper.
  HelpRequest released() => HelpRequest(
        id: id,
        kind: kind,
        urgency: urgency,
        people: people,
        createdAt: createdAt,
        senderName: senderName,
        location: location,
        locationNote: locationNote,
        note: note,
        mine: mine,
        sos: sos,
        stage: RequestStage.verified,
        stageTimes: {...stageTimes}..remove(RequestStage.assigned),
        hops: hops,
      );

  HelpRequest _copy({
    RequestStage? stage,
    Map<RequestStage, DateTime>? stageTimes,
    int? hops,
    String? helperName,
    bool? helpingIsMe,
  }) =>
      HelpRequest(
        id: id,
        kind: kind,
        urgency: urgency,
        people: people,
        createdAt: createdAt,
        senderName: senderName,
        location: location,
        locationNote: locationNote,
        note: note,
        mine: mine,
        sos: sos,
        stage: stage ?? this.stage,
        stageTimes: stageTimes ?? this.stageTimes,
        hops: hops ?? this.hops,
        helperName: helperName ?? this.helperName,
        helpingIsMe: helpingIsMe ?? this.helpingIsMe,
      );
}

/// What this phone's user is offering. Two taps plus optional detail.
class HelpOffer {
  const HelpOffer({
    required this.kinds,
    required this.since,
    this.amount = Amount.some,
    this.availability = Availability.now,
    this.availabilityNote = '',
    this.note = '',
    this.transport,
    this.capacity,
  });

  final Set<SupplyKind> kinds;
  final DateTime since;
  final Amount amount;
  final Availability availability;

  /// Filled in when [availability] is custom.
  final String availabilityNote;
  final String note;

  /// Set when [kinds] includes transportation.
  final TransportMode? transport;
  final Capacity? capacity;

  bool get offersTransport => kinds.contains(SupplyKind.transportation);
}

/// The phone's position. [accuracyMeters] is the radius it could be off by.
class LocationFix {
  const LocationFix(this.point, this.accuracyMeters);

  final LatLng point;
  final double accuracyMeters;
}
