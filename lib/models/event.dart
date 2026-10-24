/// Everything important becomes a signed, immutable event (Spec 36 and 37).
/// Old events are never changed; a later event refers back to an earlier one.
enum EventType {
  helpRequested,
  helpCancelled,
  helpAccepted,
  helpReleased,
  helpOffered,
  offerWithdrawn,
  resourceCreated,
  resourceRemoved,
  resourceConfirmed,
  resourceDisputed,
  resourceUseful,
  voteWithdrawn,
  contactAdded,
  contactRemoved,
  messageSent,
  missionAccepted,
  missionReleased,
  packagePickedUp,
  packageTransferred,
  deliveryCompleted,
}

class SignedEvent {
  const SignedEvent({
    required this.id,
    required this.type,
    required this.subject,
    required this.at,
    required this.author,
    required this.signature,
  });

  final String id;
  final EventType type;

  /// The id of the request, resource, mission or contact it is about.
  final String subject;
  final DateTime at;

  /// The signer's Resilience ID.
  final String author;

  /// Ed25519 signature, hex encoded.
  final String signature;

  /// The exact bytes that were signed. Anyone with the author's public key
  /// can check them.
  static String signedText(String id, EventType type, String subject, DateTime at) =>
      '$id|${type.name}|$subject|${at.toUtc().toIso8601String()}';

  /// The wire name used in the Spec, e.g. HELP_REQUESTED.
  String get wireName => type.name
      .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}')
      .toUpperCase();
}
