import 'dart:typed_data';

import '../db/event_dao.dart' show EventDao;
import '../gen/resilience/v1/event.pb.dart';
import '../trust/trust_engine.dart';
import '../trust/trust_roots.dart';

/// A reservation held against a resource, derived from an owner-signed
/// `RESERVATION` event. Reservations reduce *available* quantity but never
/// mutate the authoritative snapshot (spec §29).
class ReservationView {
  final String resourceId;
  final int quantity;
  final String missionId;
  final int? reservedUntilMs;

  /// The pubkey that signed the reservation (the resource owner).
  final Uint8List reservedBy;

  const ReservationView({
    required this.resourceId,
    required this.quantity,
    required this.missionId,
    required this.reservedUntilMs,
    required this.reservedBy,
  });

  /// Active relative to [nowMs]: a reservation with no expiry is always active;
  /// one with an expiry is active until that time.
  bool isActive(int nowMs) =>
      reservedUntilMs == null || reservedUntilMs! > nowMs;
}

/// A community observation attached to a resource. These *annotate* the
/// authoritative inventory (e.g. "running low") but do NOT change the
/// authoritative number (spec §29).
class ObservationView {
  final ObservationBody_Kind kind;
  final String note;
  final AmountBand observedAmount;
  final Uint8List observer;
  final int lamport;

  const ObservationView({
    required this.kind,
    required this.note,
    required this.observedAmount,
    required this.observer,
    required this.lamport,
  });
}

/// The authoritative inventory of a resource: the latest `INVENTORY_SNAPSHOT`
/// published by the owner. Never the result of distributed subtraction.
class InventoryView {
  final int quantity;
  final String unit;
  final int asOfMs;

  /// Lamport of the snapshot event, used to pick the latest.
  final int lamport;

  const InventoryView({
    required this.quantity,
    required this.unit,
    required this.asOfMs,
    required this.lamport,
  });
}

/// The folded view of a single resource.
class ResourceView {
  final String resourceId;

  /// The latest resource metadata (after applying updates/corrections).
  final ResourceBody resource;

  /// The resource's author/owner pubkey (the creator).
  final Uint8List owner;

  /// True if the resource has been withdrawn. Withdrawn resources are MARKED,
  /// not deleted (spec: still present).
  final bool withdrawn;

  /// Authoritative inventory snapshot, if the owner published one.
  final InventoryView? inventory;

  /// Active, owner-signed reservations.
  final List<ReservationView> reservations;

  /// Community observations annotating the resource.
  final List<ObservationView> observations;

  /// The three-dimensional trust profile.
  final TrustProfile trust;

  const ResourceView({
    required this.resourceId,
    required this.resource,
    required this.owner,
    required this.withdrawn,
    required this.inventory,
    required this.reservations,
    required this.observations,
    required this.trust,
  });

  /// Sum of active reservation quantities.
  int get reservedQuantity =>
      reservations.fold<int>(0, (int acc, ReservationView r) => acc + r.quantity);

  /// Available quantity = authoritative snapshot quantity minus active
  /// reservations. `null` when there is no authoritative snapshot (we do not
  /// invent a number).
  int? get availableQuantity {
    final InventoryView? inv = inventory;
    if (inv == null) return null;
    final int avail = inv.quantity - reservedQuantity;
    return avail < 0 ? 0 : avail;
  }
}

/// A help request view.
class HelpRequestView {
  final String requestId;
  final Uint8List author;
  final HelpRequestBody body;
  const HelpRequestView(
      {required this.requestId, required this.author, required this.body});
}

/// A help offer view.
class HelpOfferView {
  final String offerId;
  final Uint8List author;
  final HelpOfferBody body;
  const HelpOfferView(
      {required this.offerId, required this.author, required this.body});
}

/// A transport offer view.
class TransportOfferView {
  final String offerId;
  final Uint8List author;
  final TransportOfferBody body;
  const TransportOfferView(
      {required this.offerId, required this.author, required this.body});
}

/// An emergency alert view.
class EmergencyAlertView {
  final String alertId;
  final Uint8List author;
  final EmergencyAlertBody body;
  const EmergencyAlertView(
      {required this.alertId, required this.author, required this.body});
}

/// A pure in-memory projection of the event log into queryable application
/// state. It folds ALL events into resources, observations, help flows,
/// shelters and alerts, and attaches a [TrustProfile] to each resource.
///
/// It performs NO database writes; it is a read-model you [rebuild] from the
/// store or update incrementally with [applyEvent].
class WorldState {
  final TrustRootStore trustRoots;

  /// Evaluation time used for freshness/decay and reservation expiry. Injected
  /// so tests are deterministic; defaults to wall-clock now at rebuild time.
  final int Function() clock;

  final Map<String, ResourceView> resources = <String, ResourceView>{};
  final List<HelpRequestView> helpRequests = <HelpRequestView>[];
  final List<HelpOfferView> helpOffers = <HelpOfferView>[];
  final List<TransportOfferView> transportOffers = <TransportOfferView>[];
  final List<ResourceView> shelters = <ResourceView>[];
  final List<EmergencyAlertView> emergencyAlerts = <EmergencyAlertView>[];

  // Raw folded log, retained so trust profiles (which scan the log) and
  // incremental updates can be recomputed consistently.
  final List<SignedEvent> _log = <SignedEvent>[];

  WorldState({TrustRootStore? trustRoots, int Function()? clock})
      : trustRoots = trustRoots ?? TrustRootStore(),
        clock = clock ??
            (() => DateTime.now().toUtc().millisecondsSinceEpoch);

  /// Rebuilds the entire projection from [dao]'s full event log.
  Future<void> rebuild(EventDao dao) async {
    final List<SignedEvent> all = await dao.allEvents();
    rebuildFromEvents(all);
  }

  /// Rebuilds the entire projection from an in-memory [events] list. Useful for
  /// tests that fold a `List<SignedEvent>` without a database.
  void rebuildFromEvents(Iterable<SignedEvent> events) {
    _log
      ..clear()
      ..addAll(events);
    _recompute();
  }

  /// Incrementally folds a single [event] into the projection, then recomputes
  /// the dependent views. Kept simple and correct (full recompute over the
  /// retained log) rather than clever; the log is already in memory.
  void applyEvent(SignedEvent event) {
    _log.add(event);
    _recompute();
  }

  void _recompute() {
    resources.clear();
    helpRequests.clear();
    helpOffers.clear();
    transportOffers.clear();
    shelters.clear();
    emergencyAlerts.clear();

    final int now = clock();
    final TrustEngine engine =
        TrustEngine.fromEvents(_log, roots: trustRoots);

    // Intermediate accumulators keyed by resourceId.
    final Map<String, ResourceBody> latestResource = <String, ResourceBody>{};
    final Map<String, Uint8List> owners = <String, Uint8List>{};
    final Map<String, int> createLamport = <String, int>{};
    final Map<String, bool> withdrawn = <String, bool>{};
    final Map<String, InventoryView> inventory = <String, InventoryView>{};
    final Map<String, List<ReservationView>> reservations =
        <String, List<ReservationView>>{};
    final Map<String, List<ObservationView>> observations =
        <String, List<ObservationView>>{};

    for (final SignedEvent e in _log) {
      final EventHeader h = e.header;
      final Uint8List author = Uint8List.fromList(h.authorPubkey);
      switch (h.type) {
        case EventType.EVENT_TYPE_RESOURCE_CREATED:
          final ResourceBody body = _resource(e);
          final String id = body.resourceId;
          if (id.isEmpty) break;
          // Only the owner may re-publish (edit / relist) a resource.
          if (owners.containsKey(id) && !_sameKey(owners[id]!, author)) break;
          latestResource[id] = body;
          owners[id] = author;
          createLamport[id] = h.lamport.toInt();
          withdrawn[id] = false;
          break;

        case EventType.EVENT_TYPE_RESOURCE_UPDATED:
          final ResourceUpdateBody upd = _update(e);
          final String id = upd.resourceId;
          if (id.isEmpty) break;
          // Only the owner may change or withdraw a resource.
          if (owners.containsKey(id) && !_sameKey(owners[id]!, author)) break;
          final ResourceBody base =
              latestResource[id] ?? ResourceBody(resourceId: id);
          final ResourceBody merged = base.deepCopy();
          if (upd.hasAmount()) merged.amount = upd.amount;
          if (upd.hasAvailability()) merged.availability = upd.availability;
          if (upd.hasNotes()) merged.notes = upd.notes;
          latestResource[id] = merged;
          if (upd.hasWithdrawn()) withdrawn[id] = upd.withdrawn;
          break;

        case EventType.EVENT_TYPE_INVENTORY_SNAPSHOT:
          final InventorySnapshotBody snap = _snapshot(e);
          final String id = snap.resourceId;
          if (id.isEmpty) break;
          // Only the owner publishes the authoritative count.
          if (owners.containsKey(id) && !_sameKey(owners[id]!, author)) break;
          final int lamport = h.lamport.toInt();
          final InventoryView? prev = inventory[id];
          if (prev == null || lamport >= prev.lamport) {
            inventory[id] = InventoryView(
              quantity: snap.quantity.toInt(),
              unit: snap.unit,
              asOfMs: snap.asOfMs.toInt(),
              lamport: lamport,
            );
          }
          break;

        case EventType.EVENT_TYPE_RESERVATION:
          final ReservationBody res = _reservation(e);
          final String id = res.resourceId;
          if (id.isEmpty) break;
          reservations.putIfAbsent(id, () => <ReservationView>[]).add(
                ReservationView(
                  resourceId: id,
                  quantity: res.quantity.toInt(),
                  missionId: res.missionId,
                  reservedUntilMs:
                      res.hasReservedUntilMs() ? res.reservedUntilMs.toInt() : null,
                  reservedBy: author,
                ),
              );
          break;

        case EventType.EVENT_TYPE_RESOURCE_OBSERVED:
        case EventType.EVENT_TYPE_RESOURCE_CONFIRMED:
        case EventType.EVENT_TYPE_RESOURCE_DISPUTED:
        case EventType.EVENT_TYPE_RESOURCE_USEFUL:
          final ObservationBody obs = _observation(e);
          final String id = obs.resourceId;
          if (id.isEmpty) break;
          observations.putIfAbsent(id, () => <ObservationView>[]).add(
                ObservationView(
                  kind: _kindFor(h.type, obs),
                  note: obs.note,
                  observedAmount: obs.observedAmount,
                  observer: author,
                  lamport: h.lamport.toInt(),
                ),
              );
          break;

        case EventType.EVENT_TYPE_HELP_REQUESTED:
          final HelpRequestBody body = _helpRequest(e);
          helpRequests.add(HelpRequestView(
              requestId: body.requestId, author: author, body: body));
          break;

        case EventType.EVENT_TYPE_HELP_OFFERED:
          final HelpOfferBody body = _helpOffer(e);
          helpOffers.add(HelpOfferView(
              offerId: body.offerId, author: author, body: body));
          break;

        case EventType.EVENT_TYPE_TRANSPORT_OFFERED:
          final TransportOfferBody body = _transportOffer(e);
          transportOffers.add(TransportOfferView(
              offerId: body.offerId, author: author, body: body));
          break;

        case EventType.EVENT_TYPE_SHELTER_CREATED:
          // Shelters are published as resources flagged is_shelter; a dedicated
          // SHELTER_CREATED carries a ResourceBody too.
          final ResourceBody body = _resource(e);
          final String id = body.resourceId;
          if (id.isEmpty) break;
          latestResource[id] = body;
          owners[id] = author;
          createLamport[id] = h.lamport.toInt();
          withdrawn.putIfAbsent(id, () => false);
          break;

        case EventType.EVENT_TYPE_EMERGENCY_ALERT:
          final EmergencyAlertBody body = _alert(e);
          // Alerts are authoritative: only verified organization members may
          // issue one. A community member's "alert" is ignored, not shown.
          if (engine.certGraph.provenanceOf(author,
                  roots: trustRoots, revocations: engine.revocations) !=
              ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG) {
            break;
          }
          emergencyAlerts.add(EmergencyAlertView(
              alertId: body.alertId, author: author, body: body));
          break;

        default:
          break;
      }
    }

    // Materialize resource views with trust profiles.
    for (final MapEntry<String, ResourceBody> entry
        in latestResource.entries) {
      final String id = entry.key;
      final List<ReservationView> allRes =
          reservations[id] ?? const <ReservationView>[];
      final List<ReservationView> activeRes = allRes
          .where((ReservationView r) => r.isActive(now))
          .toList(growable: false);
      final ResourceView view = ResourceView(
        resourceId: id,
        resource: entry.value,
        owner: owners[id] ?? Uint8List(0),
        withdrawn: withdrawn[id] ?? false,
        inventory: inventory[id],
        reservations: activeRes,
        observations: observations[id] ?? const <ObservationView>[],
        trust: engine.profileForResource(id, _log, nowMs: now),
      );
      resources[id] = view;
      if (view.resource.isShelter ||
          view.resource.category ==
              ResourceCategory.RESOURCE_CATEGORY_SHELTER) {
        shelters.add(view);
      }
    }
  }

  /// Whether [key] is a verified organization member under the trust roots this
  /// device holds (a trusted root itself, or certified by a chain from one).
  ProvenanceKind provenanceOf(List<int> key) {
    final TrustEngine engine = TrustEngine.fromEvents(_log, roots: trustRoots);
    return engine.certGraph.provenanceOf(key,
        roots: trustRoots, revocations: engine.revocations);
  }

  static bool _sameKey(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Resources ordered by trust rank (confirmed + fresh + verified first),
  /// with low-confidence resources ranked LAST but still PRESENT (spec §10).
  /// Withdrawn resources are included (marked), per spec.
  List<ResourceView> rankedResources() {
    final List<ResourceView> all = resources.values.toList();
    all.sort((ResourceView a, ResourceView b) {
      final int byRank =
          b.trust.rankScore.compareTo(a.trust.rankScore);
      if (byRank != 0) return byRank;
      // Deterministic tie-break: fresher first, then resourceId.
      final int byFresh =
          a.trust.freshness.ageMs.compareTo(b.trust.freshness.ageMs);
      if (byFresh != 0) return byFresh;
      return a.resourceId.compareTo(b.resourceId);
    });
    return all;
  }

  // --- decode helpers (never throw into the fold) ---

  ResourceBody _resource(SignedEvent e) {
    try {
      return ResourceBody.fromBuffer(e.body);
    } catch (_) {
      return ResourceBody();
    }
  }

  ResourceUpdateBody _update(SignedEvent e) {
    try {
      return ResourceUpdateBody.fromBuffer(e.body);
    } catch (_) {
      return ResourceUpdateBody();
    }
  }

  InventorySnapshotBody _snapshot(SignedEvent e) {
    try {
      return InventorySnapshotBody.fromBuffer(e.body);
    } catch (_) {
      return InventorySnapshotBody();
    }
  }

  ReservationBody _reservation(SignedEvent e) {
    try {
      return ReservationBody.fromBuffer(e.body);
    } catch (_) {
      return ReservationBody();
    }
  }

  ObservationBody _observation(SignedEvent e) {
    try {
      return ObservationBody.fromBuffer(e.body);
    } catch (_) {
      return ObservationBody();
    }
  }

  HelpRequestBody _helpRequest(SignedEvent e) {
    try {
      return HelpRequestBody.fromBuffer(e.body);
    } catch (_) {
      return HelpRequestBody();
    }
  }

  HelpOfferBody _helpOffer(SignedEvent e) {
    try {
      return HelpOfferBody.fromBuffer(e.body);
    } catch (_) {
      return HelpOfferBody();
    }
  }

  TransportOfferBody _transportOffer(SignedEvent e) {
    try {
      return TransportOfferBody.fromBuffer(e.body);
    } catch (_) {
      return TransportOfferBody();
    }
  }

  EmergencyAlertBody _alert(SignedEvent e) {
    try {
      return EmergencyAlertBody.fromBuffer(e.body);
    } catch (_) {
      return EmergencyAlertBody();
    }
  }

  ObservationBody_Kind _kindFor(EventType type, ObservationBody body) {
    switch (type) {
      case EventType.EVENT_TYPE_RESOURCE_CONFIRMED:
        return ObservationBody_Kind.KIND_CONFIRMED;
      case EventType.EVENT_TYPE_RESOURCE_DISPUTED:
        return ObservationBody_Kind.KIND_DISPUTED;
      case EventType.EVENT_TYPE_RESOURCE_USEFUL:
        return ObservationBody_Kind.KIND_USEFUL;
      case EventType.EVENT_TYPE_RESOURCE_OBSERVED:
        return body.hasKind() ? body.kind : ObservationBody_Kind.KIND_OBSERVED;
      default:
        return ObservationBody_Kind.KIND_UNSPECIFIED;
    }
  }
}
