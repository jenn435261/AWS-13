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

  /// Whether this supply has passed its `available_until_ms` relative to [now].
  /// A supply with no end date (`available_until_ms == 0`) never expires.
  /// Expired supplies are auto-hidden from the map (see [WorldState.mapResources])
  /// but remain visible, marked "expired", in the owner's My Supplies list.
  bool isExpired(int now) {
    final int until = resource.availableUntilMs.toInt();
    return until > 0 && until <= now;
  }
}

/// A help request view.
///
/// [closed] is true once the request's AUTHOR has published a
/// `HELP_REQUEST_CLOSED` for it (owner-only; a close from any other key is
/// ignored by the fold). A closed request is kept in the projection — marked,
/// struck through, filterable — rather than deleted, so the history stays
/// verifiable and helpers who already saw it understand it was resolved.
class HelpRequestView {
  final String requestId;
  final Uint8List author;
  final HelpRequestBody body;

  /// Whether the author has closed/cancelled this request.
  final bool closed;

  /// Optional freeform reason the author gave when closing (may be empty).
  final String closeReason;

  const HelpRequestView({
    required this.requestId,
    required this.author,
    required this.body,
    this.closed = false,
    this.closeReason = '',
  });
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

/// A folded, still-active location share.
///
/// This is the fold's privacy-preserving projection of a `LOCATION_SHARE`: it
/// carries only routing/visibility metadata (author, scope, expiry) and the
/// OPAQUE `encryptedPoint`/coarse `publicPoint` exactly as they rode on the
/// wire. The fold NEVER decrypts and NEVER logs a coordinate; resolving the
/// precise point for an authorized viewer happens later in
/// `ActiveShares.incomingFor` using that viewer's Signal sessions.
///
/// A share is present here only while it is active: `now < expiresMs` AND no
/// `LOCATION_STOP` by the same author has superseded it (a stop for its
/// `shareId`, or an author-wide stop with an empty `shareId`). Only the sharer
/// (the event author) can stop or expire their own share — a `LOCATION_STOP`
/// from anyone else is ignored because stops are folded per-author.
class LocationShareView {
  /// The sharer's (author) 32-byte Ed25519 public key.
  final Uint8List author;

  /// The share id, unique per author.
  final String shareId;

  /// The audience scope: `contact:<pubkeyhex>`, `channel:<id>`, or `public`.
  final String scope;

  /// Epoch millis at which this share self-expires.
  final int expiresMs;

  /// Opaque ciphertext of the precise point for contact/channel scopes (empty
  /// for public beacons). The fold treats this as bytes and never decrypts it.
  final Uint8List encryptedPoint;

  /// The coarse, clear point for a public beacon (unset for contact/channel).
  final GeoPoint? publicPoint;

  /// Free-text note attached to the share (may be empty).
  final String note;

  /// Monotonic per-share sequence (latest wins when folding re-shares).
  final int seq;

  const LocationShareView({
    required this.author,
    required this.shareId,
    required this.scope,
    required this.expiresMs,
    required this.encryptedPoint,
    required this.publicPoint,
    required this.note,
    required this.seq,
  });

  /// True when this share's audience is the single contact [viewerHex]
  /// (lowercase pubkey hex), i.e. `scope == 'contact:<viewerHex>'`.
  bool isAddressedToContact(String viewerHex) =>
      scope == 'contact:$viewerHex';

  /// True when this share is a public beacon anyone may see.
  bool get isPublic => scope == 'public';

  /// True when this share targets the channel [channelId]
  /// (`scope == 'channel:<channelId>'`).
  bool isForChannel(String channelId) => scope == 'channel:$channelId';
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

  /// Active (non-expired, non-stopped) location shares across all authors.
  /// Use [locationSharesVisibleTo] to filter to shares this device may see.
  final List<LocationShareView> locationShares = <LocationShareView>[];

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
    locationShares.clear();

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

    // Location sharing: latest share per (author, shareId) and per-author stop
    // state. Stops are folded per-author so ONLY the sharer can revoke/expire
    // their own share (an abuse rule enforced here, not by convention).
    final Map<String, _ShareFold> shareByKey = <String, _ShareFold>{};
    final Map<String, _StopFold> stopByAuthor = <String, _StopFold>{};

    // Help requests folded per request id so a HELP_REQUEST_CLOSED can mark the
    // matching request closed. The owner (first author of the id) is the only
    // key whose close is honored. `requestOrder` preserves first-seen order.
    final Map<String, _RequestFold> requestByKey = <String, _RequestFold>{};
    int requestOrder = 0;

    // Emergency alerts folded per alert id. An alert is recalled by publishing
    // a NEW EMERGENCY_ALERT with the SAME alert_id and `expires_ms` in the past
    // (author-only). The latest event for an id by its original author wins, so
    // a recalled/expired alert simply drops out below.
    final Map<String, _AlertFold> alertByKey = <String, _AlertFold>{};
    int alertOrder = 0;

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
          if (body.requestId.isEmpty) break;
          // First writer of a request id owns it; a later HELP_REQUESTED under
          // the same id from a different key cannot hijack it.
          final _RequestFold? prevReq = requestByKey[body.requestId];
          if (prevReq != null && !_sameKey(prevReq.author, author)) break;
          requestByKey[body.requestId] = _RequestFold(
            author: author,
            body: body,
            closed: prevReq?.closed ?? false,
            closeReason: prevReq?.closeReason ?? '',
            order: requestOrder++,
          );
          break;

        case EventType.EVENT_TYPE_HELP_REQUEST_CLOSED:
          final HelpRequestClosedBody close = _helpClose(e);
          if (close.requestId.isEmpty) break;
          final _RequestFold? req = requestByKey[close.requestId];
          // Owner-only: a close is honored ONLY when authored by the same key
          // that authored the original request. A close from any other key is
          // ignored (abuse rule enforced here, not by convention).
          if (req == null || !_sameKey(req.author, author)) break;
          req.closed = true;
          req.closeReason = close.reason;
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
          if (body.alertId.isEmpty) break;
          // Alerts are authoritative: only verified organization members may
          // issue one. A community member's "alert" is ignored, not shown.
          if (engine.certGraph.provenanceOf(author,
                  roots: trustRoots, revocations: engine.revocations) !=
              ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG) {
            break;
          }
          final _AlertFold? prevAlert = alertByKey[body.alertId];
          // Author-only recall/update: only the original author of an alert_id
          // may supersede (recall) it. A different verified org cannot recall
          // someone else's alert.
          if (prevAlert != null && !_sameKey(prevAlert.author, author)) break;
          final int lamport = h.lamport.toInt();
          final int createdAtMs = h.createdAtMs.toInt();
          // Latest author event wins by (lamport, created_at_ms), mirroring how
          // location shares supersede by (seq, lamport): lamport is the primary
          // logical ordering (monotonic per author, so a recall always advances
          // it) and created_at_ms breaks the tie when two events share a
          // lamport, so an out-of-order recall carrying the same lamport as the
          // original but a later wall-clock still takes effect. See
          // docs/DECISIONS.md.
          if (prevAlert == null ||
              lamport > prevAlert.lamport ||
              (lamport == prevAlert.lamport &&
                  createdAtMs >= prevAlert.createdAtMs)) {
            alertByKey[body.alertId] = _AlertFold(
              author: author,
              body: body,
              lamport: lamport,
              createdAtMs: createdAtMs,
              order: prevAlert?.order ?? alertOrder++,
            );
          }
          break;

        case EventType.EVENT_TYPE_LOCATION_SHARE:
          final LocationShareBody body = _locationShare(e);
          if (body.shareId.isEmpty) break;
          final String authorHex = _hexOf(author);
          final String key = '$authorHex/${body.shareId}';
          final int seq = body.seq.toInt();
          final int lamport = h.lamport.toInt();
          final _ShareFold? prev = shareByKey[key];
          // Latest re-share wins: higher seq, then higher lamport.
          if (prev == null ||
              seq > prev.seq ||
              (seq == prev.seq && lamport > prev.lamport)) {
            shareByKey[key] = _ShareFold(
              author: author,
              body: body,
              seq: seq,
              lamport: lamport,
            );
          }
          break;

        case EventType.EVENT_TYPE_LOCATION_STOP:
          final LocationStopBody stop = _locationStop(e);
          // Folded under the AUTHOR: a stop only affects that author's own
          // shares, so a non-owner can never revoke someone else's share.
          final _StopFold state =
              stopByAuthor.putIfAbsent(_hexOf(author), () => _StopFold());
          if (stop.shareId.isEmpty) {
            state.stopAll = true;
          } else {
            state.stoppedIds.add(stop.shareId);
          }
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

    // Materialize help requests in first-seen order, carrying the closed flag.
    final List<_RequestFold> reqs = requestByKey.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final _RequestFold r in reqs) {
      helpRequests.add(HelpRequestView(
        requestId: r.body.requestId,
        author: r.author,
        body: r.body,
        closed: r.closed,
        closeReason: r.closeReason,
      ));
    }

    // Materialize emergency alerts: drop any whose latest version has expired
    // (which also covers an author recall — a re-issue of the same alert_id
    // with expires_ms in the past). An alert with no expiry (expires_ms == 0)
    // never expires.
    final List<_AlertFold> alertList = alertByKey.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final _AlertFold a in alertList) {
      final int expires = a.body.expiresMs.toInt();
      if (expires != 0 && expires <= now) continue; // expired or recalled
      emergencyAlerts.add(EmergencyAlertView(
          alertId: a.body.alertId, author: a.author, body: a.body));
    }

    // Materialize the still-active location shares. A share survives only while
    // it has not expired AND the author has not stopped it (per-share or an
    // author-wide stop). The fold carries ciphertext opaquely; it never
    // decrypts or logs a coordinate.
    for (final _ShareFold rec in shareByKey.values) {
      final LocationShareBody body = rec.body;
      final int expiresMs = body.expiresMs.toInt();
      if (expiresMs <= now) continue; // self-expiry
      final _StopFold? stop = stopByAuthor[_hexOf(rec.author)];
      if (stop != null &&
          (stop.stopAll || stop.stoppedIds.contains(body.shareId))) {
        continue; // revoked by the sharer
      }
      locationShares.add(LocationShareView(
        author: rec.author,
        shareId: body.shareId,
        scope: body.scope,
        expiresMs: expiresMs,
        encryptedPoint: Uint8List.fromList(body.encryptedPoint),
        publicPoint: body.hasPublicPoint() ? body.publicPoint : null,
        note: body.note,
        seq: rec.seq,
      ));
    }
    locationShares.sort((a, b) => b.seq.compareTo(a.seq));
  }

  /// Active location shares this device is the audience for: shares addressed
  /// to [viewerPubkey] as a `contact:<hex>`, public beacons, and any channel in
  /// [channelIds]. A non-audience contact never appears here, so the UI can
  /// never surface a share (or attempt to decrypt a coordinate) it was not
  /// addressed to.
  List<LocationShareView> locationSharesVisibleTo(
    List<int> viewerPubkey, {
    Set<String> channelIds = const <String>{},
    bool includePublic = true,
  }) {
    final String viewerHex = _hexOf(viewerPubkey);
    return locationShares.where((LocationShareView s) {
      if (s.isAddressedToContact(viewerHex)) return true;
      if (includePublic && s.isPublic) return true;
      if (s.scope.startsWith('channel:')) {
        return channelIds.contains(s.scope.substring('channel:'.length));
      }
      return false;
    }).toList(growable: false);
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

  /// Resources eligible to show on the map: ranked, excluding withdrawn
  /// supplies and supplies whose `available_until_ms` has passed relative to
  /// the fold's injected clock (auto-hide expired supplies). Expired supplies
  /// are NOT removed from the projection — the owner still sees them, marked
  /// "expired", in My Supplies — they are only filtered off the shared map.
  List<ResourceView> mapResources() {
    final int now = clock();
    return rankedResources()
        .where((ResourceView r) => !r.withdrawn && !r.isExpired(now))
        .toList(growable: false);
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

  HelpRequestClosedBody _helpClose(SignedEvent e) {
    try {
      return HelpRequestClosedBody.fromBuffer(e.body);
    } catch (_) {
      return HelpRequestClosedBody();
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

  LocationShareBody _locationShare(SignedEvent e) {
    try {
      return LocationShareBody.fromBuffer(e.body);
    } catch (_) {
      return LocationShareBody();
    }
  }

  LocationStopBody _locationStop(SignedEvent e) {
    try {
      return LocationStopBody.fromBuffer(e.body);
    } catch (_) {
      return LocationStopBody();
    }
  }

  static String _hexOf(List<int> bytes) {
    final StringBuffer sb = StringBuffer();
    for (final int b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
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

/// Fold accumulator for the latest `LOCATION_SHARE` per (author, shareId).
class _ShareFold {
  _ShareFold({
    required this.author,
    required this.body,
    required this.seq,
    required this.lamport,
  });

  final Uint8List author;
  final LocationShareBody body;
  final int seq;
  final int lamport;
}

/// Fold accumulator for an author's `LOCATION_STOP` state.
class _StopFold {
  bool stopAll = false;
  final Set<String> stoppedIds = <String>{};
}

/// Fold accumulator for a help request and its owner-only close state.
class _RequestFold {
  _RequestFold({
    required this.author,
    required this.body,
    required this.closed,
    required this.closeReason,
    required this.order,
  });

  final Uint8List author;
  final HelpRequestBody body;
  bool closed;
  String closeReason;
  final int order;
}

/// Fold accumulator for the latest `EMERGENCY_ALERT` per alert id (author-only
/// supersede/recall).
class _AlertFold {
  _AlertFold({
    required this.author,
    required this.body,
    required this.lamport,
    required this.createdAtMs,
    required this.order,
  });

  final Uint8List author;
  final EmergencyAlertBody body;
  final int lamport;
  final int createdAtMs;
  final int order;
}
