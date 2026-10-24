import 'package:latlong2/latlong.dart';

/// What an [Envelope] carries off the phone. Each one maps to a signed event
/// on the wire (docs/app-backend-contract.md).
enum EnvelopeKind {
  helpRequest,
  sos,
  helpCancelled,
  helpAccepted,
  helpReleased,
  offer,
  offerWithdrawn,
  resourceCreated,
  resourceRemoved,
  vote,
  message,
  missionAccepted,
  missionReleased,
  packagePickedUp,
  packageTransferred,
  deliveryCompleted,

  /// The carrier's live position, only while carrying a delivery.
  liveLocation,

  /// Tells the delivery's people to stop showing the carrier's position.
  locationStopped,
}

/// Which items leave first when routes are scarce. An SOS never waits
/// behind a vote.
enum SendPriority { urgent, normal, low }

/// One item waiting to leave the phone: a message or an event. The outbox
/// keeps it until a route acknowledges it, keyed by [id].
class Envelope {
  const Envelope({
    required this.id,
    required this.kind,
    required this.subject,
    required this.author,
    required this.createdAt,
    this.fields = const {},
    this.location,
  });

  /// Unique for this item. Routes and receivers use it to drop duplicates.
  final String id;
  final EnvelopeKind kind;

  /// The request, resource, mission or channel it is about.
  final String subject;

  /// The sender's Resilience ID.
  final String author;
  final DateTime createdAt;

  /// Plain values only (strings, numbers, booleans, lists of them). Never
  /// coordinates: those go in [location], where the privacy rule checks them.
  final Map<String, Object?> fields;

  /// The only coordinates an envelope may carry. See [LocationPolicy].
  final LatLng? location;

  SendPriority get priority => switch (kind) {
        EnvelopeKind.sos ||
        EnvelopeKind.helpRequest ||
        EnvelopeKind.helpCancelled ||
        EnvelopeKind.helpAccepted ||
        EnvelopeKind.helpReleased ||
        EnvelopeKind.liveLocation ||
        EnvelopeKind.locationStopped =>
          SendPriority.urgent,
        EnvelopeKind.vote => SendPriority.low,
        _ => SendPriority.normal,
      };

  /// A newer envelope with the same key replaces an older one that has not
  /// left yet: only the carrier's latest position matters.
  String? get replaceKey =>
      kind == EnvelopeKind.liveLocation ? 'live:$subject' : null;

  /// Direct, restricted and mission messages, and live positions, are for
  /// chosen people only. Until end-to-end encryption exists they never go
  /// through a Resilience Node or the cloud, which store what they relay.
  bool get needsEndToEnd {
    if (kind == EnvelopeKind.liveLocation) return true;
    if (kind != EnvelopeKind.message) return false;
    final channel = fields['channelType'];
    return channel == 'direct' || channel == 'restricted' || channel == 'mission';
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'subject': subject,
        'author': author,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (fields.isNotEmpty) 'fields': fields,
        if (location != null)
          'location': {'lat': location!.latitude, 'lon': location!.longitude},
      };

  static Envelope fromJson(Map<String, Object?> json) {
    final at = json['location'] as Map<String, Object?>?;
    return Envelope(
      id: json['id']! as String,
      kind: EnvelopeKind.values.byName(json['kind']! as String),
      subject: json['subject']! as String,
      author: json['author']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      fields: Map<String, Object?>.from(
        (json['fields'] as Map<String, Object?>?) ?? const {},
      ),
      location: at == null
          ? null
          : LatLng((at['lat']! as num).toDouble(), (at['lon']! as num).toDouble()),
    );
  }

  /// The same envelope without coordinates.
  Envelope withoutLocation() => Envelope(
        id: id,
        kind: kind,
        subject: subject,
        author: author,
        createdAt: createdAt,
        fields: fields,
      );
}
