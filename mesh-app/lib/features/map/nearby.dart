import 'package:latlong2/latlong.dart';

import '../../models/help.dart';
import '../../models/resource.dart';
import '../../utils/format.dart';

/// Something on the map that gets a card in the swipeable row.
sealed class Nearby {
  const Nearby(this.distance);

  /// Meters from the person, or from the area's center when the phone
  /// doesn't know where it is (then the cards don't show distances).
  final double distance;
  String get id;
  LatLng get point;
}

class NearbyRequest extends Nearby {
  const NearbyRequest(this.request, super.distance);

  final HelpRequest request;
  @override
  String get id => request.id;
  @override
  LatLng get point => request.location!;
}

class NearbyResource extends Nearby {
  const NearbyResource(this.resource, super.distance);

  final Resource resource;
  @override
  String get id => resource.id;
  @override
  LatLng get point => resource.location;
}

/// SOS first, then by how soon help is needed.
int _urgencyRank(HelpRequest r) => r.sos ? -1 : r.urgency.index;

/// The card row, neighbor first. Whoever opens the map is most often a
/// neighbor or a bystander, so it leads with how they can help: other
/// people's open requests, most urgent and then nearest. Requests this phone
/// is already helping with come next, then resources, nearest first, with
/// stale ones ranked lower but still shown (Spec 10, 66). This phone's own
/// requests have their own pins and screen, so they get no card.
List<Nearby> nearbyItems({
  required List<HelpRequest> requests,
  required List<Resource> resources,
  required LatLng from,
  bool showRequests = true,
  bool showFacilities = true,
  bool showLive = true,
}) {
  final open = <NearbyRequest>[];
  final helping = <NearbyRequest>[];
  if (showRequests) {
    for (final r in requests) {
      if (r.mine || r.location == null) continue;
      final item = NearbyRequest(r, metersBetween(from, r.location!));
      if (r.isOpen) {
        open.add(item);
      } else if (r.helpingIsMe && r.stage != RequestStage.resolved) {
        helping.add(item);
      }
    }
  }
  open.sort((a, b) {
    final byUrgency = _urgencyRank(a.request).compareTo(_urgencyRank(b.request));
    return byUrgency != 0 ? byUrgency : a.distance.compareTo(b.distance);
  });
  helping.sort((a, b) => a.distance.compareTo(b.distance));

  double rank(NearbyResource n) => n.distance * (n.resource.isStale() ? 3 : 1);
  final places = [
    for (final r in resources)
      if (r.kind.isFacility ? showFacilities : showLive)
        NearbyResource(r, metersBetween(from, r.location)),
  ]..sort((a, b) => rank(a).compareTo(rank(b)));

  return [...open, ...helping, ...places];
}
