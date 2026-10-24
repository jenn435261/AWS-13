// People, organizations and the channels they talk on (Spec 11 to 18).

enum ContactKind { person, organization }

/// How a contact was added. Only an in-person QR scan proves the key
/// belongs to the person you met.
enum ContactSource { qr, username, phone, directory }

class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.kind,
    required this.source,
    this.verifiedOrganization = false,
  });

  /// The Resilience ID: derived from their public key, never a phone number.
  final String id;
  final String name;
  final ContactKind kind;
  final ContactSource source;

  /// Certified by a trusted organization (Spec section 54).
  final bool verifiedOrganization;

  bool get metInPerson => source == ContactSource.qr;
}

/// Spec section 18: who can read a channel.
enum ChannelType { direct, public, community, restricted, mission }

class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.type,
    this.readOnly = false,
  });

  final String id;
  final String name;
  final ChannelType type;

  /// Only verified organizations post here, e.g. emergency alerts.
  final bool readOnly;
}

/// An organization in the trust hierarchy (Spec section 54).
class TrustedOrganization {
  const TrustedOrganization({
    required this.name,
    required this.category,
    required this.certifiedBy,
    required this.checkedAt,
  });

  final String name;
  final String category;
  final String certifiedBy;

  /// When this phone last received its certificate and revocation status.
  final DateTime checkedAt;
}
