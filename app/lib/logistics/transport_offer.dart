import 'dart:typed_data';

import '../core/event_factory.dart';
import '../core/lamport_clock.dart';
import '../core/signing.dart';
import '../gen/resilience/v1/event.pb.dart';

/// Transport offers and mission matching (spec §22, §29).
///
/// A courier publishes a signed `TRANSPORT_OFFERED` event describing how they
/// can move cargo (mode, capacity band, availability, coarse location). The
/// matcher ranks offers against a transport *request* (the cargo a mission
/// needs moved) using a slim heuristic: category/capacity fit, availability,
/// and proximity by H3 bucket.

/// Builder for `TRANSPORT_OFFERED` events.
class TransportOfferEvents {
  TransportOfferEvents({EventFactory? factory})
      : _factory = factory ?? EventFactory();

  final EventFactory _factory;

  /// `TRANSPORT_OFFERED`, signed by the offering courier.
  Future<SignedEvent> offered({
    required KeyPairData offererKeyPair,
    required LamportClock clock,
    required String offerId,
    required TransportMode mode,
    required CapacityBand capacity,
    Availability availability = Availability.AVAILABILITY_NOW,
    GeoPoint? location,
    List<int>? prevEventId,
  }) {
    final body = TransportOfferBody(
      offerId: offerId,
      mode: mode,
      capacity: capacity,
      availability: availability,
      location: location,
    );
    return _factory.buildFromMessage(
      keyPair: offererKeyPair,
      clock: clock,
      type: EventType.EVENT_TYPE_TRANSPORT_OFFERED,
      body: body,
      prevEventId: prevEventId,
    );
  }
}

/// A folded view of a transport offer plus the courier (author) who made it.
class TransportOfferView {
  TransportOfferView({
    required this.offerId,
    required List<int> offerer,
    required this.mode,
    required this.capacity,
    required this.availability,
    required this.location,
  }) : offerer = Uint8List.fromList(offerer);

  factory TransportOfferView.fromEvent(SignedEvent e) {
    final TransportOfferBody b = TransportOfferBody.fromBuffer(e.body);
    return TransportOfferView(
      offerId: b.offerId,
      offerer: e.header.authorPubkey,
      mode: b.mode,
      capacity: b.capacity,
      availability: b.availability,
      location: b.hasLocation() ? b.location : null,
    );
  }

  final String offerId;
  final Uint8List offerer;
  final TransportMode mode;
  final CapacityBand capacity;
  final Availability availability;
  final GeoPoint? location;
}

/// The cargo-moving need a mission has, fed to [matchOffers].
class TransportRequest {
  const TransportRequest({
    required this.requestId,
    required this.category,
    required this.requiredCapacity,
    this.pickupH3,
  });

  final String requestId;
  final ResourceCategory category;

  /// The minimum capacity band the cargo needs.
  final CapacityBand requiredCapacity;

  /// Coarse H3 bucket of the pickup (for proximity scoring); `null` if unknown.
  final int? pickupH3;
}

/// A ranked candidate carrier.
class RankedOffer {
  const RankedOffer(this.offer, this.score);
  final TransportOfferView offer;

  /// Higher is better; `0` when the offer cannot serve the request.
  final int score;
}

/// Rank [offers] against [request] with a slim heuristic.
///
/// Scoring (additive, only for serviceable offers):
///  * capacity: offer capacity >= required -> +3, with a small bonus for an
///    exact fit (avoid wasting a truck on a small parcel);
///  * availability: NOW -> +2, TODAY -> +1;
///  * proximity: same H3 bucket as the pickup -> +2.
///
/// Offers whose capacity cannot meet the requirement are excluded (score 0 and
/// dropped). The result is sorted by descending score, ties broken by offerId
/// for determinism.
List<RankedOffer> matchOffers(
  TransportRequest request,
  List<TransportOfferView> offers,
) {
  final List<RankedOffer> ranked = <RankedOffer>[];
  for (final TransportOfferView o in offers) {
    final int cap = o.capacity.value;
    final int need = request.requiredCapacity.value;

    // Unknown/unspecified capacity cannot serve; too-small cannot serve.
    if (cap == CapacityBand.CAPACITY_BAND_UNSPECIFIED.value) continue;
    if (need != CapacityBand.CAPACITY_BAND_UNSPECIFIED.value && cap < need) {
      continue;
    }

    int score = 3; // base: capacity fits
    if (cap == need) score += 1; // exact fit bonus

    switch (o.availability) {
      case Availability.AVAILABILITY_NOW:
        score += 2;
        break;
      case Availability.AVAILABILITY_TODAY:
        score += 1;
        break;
      default:
        break;
    }

    if (request.pickupH3 != null &&
        o.location != null &&
        o.location!.hasH3Cell() &&
        o.location!.h3Cell.toInt() == request.pickupH3) {
      score += 2;
    }

    ranked.add(RankedOffer(o, score));
  }

  ranked.sort((a, b) {
    if (a.score != b.score) return b.score - a.score;
    return a.offer.offerId.compareTo(b.offer.offerId);
  });
  return ranked;
}
