import 'dart:math' as math;

import '../db/event_dao.dart' show AuthorKey;
import '../gen/resilience/v1/event.pb.dart';
import 'org_certs.dart';
import 'revocation.dart';
import 'trust_roots.dart';

/// Coarse confidence buckets derived from the three trust dimensions.
///
/// This is a *display convenience*, never a replacement for the dimensions.
/// Low-confidence information stays visible (spec §10); the band only hints at
/// how to present it (badge/colour), and ranking uses it to order — never to
/// hide.
enum ConfidenceBand {
  /// Strong corroboration and/or a verified source, and still reasonably fresh.
  high,

  /// Some corroboration or a verified source.
  medium,

  /// Weakly corroborated, stale, or disputed.
  low,

  /// No corroboration at all yet (a lone report). Still shown.
  unconfirmed,
}

/// The SOURCE dimension (spec §9): who authored the information.
class Provenance {
  final ProvenanceKind kind;

  /// True when the author held verified-org provenance that was lost to a
  /// revocation. The UI flags this ("was verified, now revoked") rather than
  /// silently dropping the item.
  final bool revoked;

  const Provenance({required this.kind, this.revoked = false});

  bool get isVerifiedOrg => kind == ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG;

  @override
  String toString() =>
      'Provenance(${kind.name}${revoked ? ', revoked' : ''})';
}

/// The CORROBORATION dimension (spec §9): independent confirmations and
/// disputes by *other* identities, de-duplicated so each observer counts once.
class Corroboration {
  final int confirmCount;
  final int disputeCount;
  final int usefulCount;

  /// Number of distinct observers that contributed any observation (excluding
  /// the resource's own author).
  final int distinctObservers;

  const Corroboration({
    required this.confirmCount,
    required this.disputeCount,
    required this.usefulCount,
    required this.distinctObservers,
  });

  static const Corroboration none = Corroboration(
    confirmCount: 0,
    disputeCount: 0,
    usefulCount: 0,
    distinctObservers: 0,
  );

  /// Net corroboration: confirmations minus disputes.
  int get net => confirmCount - disputeCount;

  @override
  String toString() =>
      'Corroboration(confirm=$confirmCount, dispute=$disputeCount, '
      'useful=$usefulCount, observers=$distinctObservers)';
}

/// The FRESHNESS dimension (spec §9, §66): how recent the newest relevant event
/// is, plus a decayed factor so staleness is visible rather than binary.
class Freshness {
  /// Timestamp (unix millis) of the most recent relevant event, or `null` if
  /// unknown.
  final int? lastObservedMs;

  /// Age in millis relative to the evaluation time ("now").
  final int ageMs;

  /// Decayed freshness in [0, 1]: 1.0 is brand new, approaching 0 as it ages.
  final double decayFactor;

  const Freshness({
    required this.lastObservedMs,
    required this.ageMs,
    required this.decayFactor,
  });

  @override
  String toString() =>
      'Freshness(ageMs=$ageMs, decay=${decayFactor.toStringAsFixed(3)})';
}

/// The full, three-dimensional trust profile for a resource. The three
/// dimensions are kept *separately accessible*; [band] and [rankScore] are
/// derived conveniences for presentation and ordering only.
class TrustProfile {
  final String resourceId;
  final Provenance source;
  final Corroboration corroboration;
  final Freshness freshness;
  final ConfidenceBand band;

  /// Ordering key: higher means "surface earlier". Combines the dimensions but
  /// is ONLY a sort key — the UI renders the dimensions, not this number.
  final double rankScore;

  const TrustProfile({
    required this.resourceId,
    required this.source,
    required this.corroboration,
    required this.freshness,
    required this.band,
    required this.rankScore,
  });

  @override
  String toString() => 'TrustProfile($resourceId, $source, $corroboration, '
      '$freshness, band=$band, rank=${rankScore.toStringAsFixed(3)})';
}

/// Computes [TrustProfile]s by folding the event log.
///
/// The engine is a pure function of (events, trusted roots, now). It never
/// collapses SOURCE, CORROBORATION and FRESHNESS into one number for display;
/// it exposes them independently and offers [TrustProfile.band] /
/// [TrustProfile.rankScore] purely for presentation and ordering.
class TrustEngine {
  /// Half-life of freshness decay. After this much time the freshness factor
  /// halves. Two hours matches the "data visibly decays within a shift" feel of
  /// spec §66 without dropping older data to zero.
  static const int freshnessHalfLifeMs = 2 * 60 * 60 * 1000;

  final TrustRootStore roots;
  final RevocationSet revocations;
  final OrgCertGraph certGraph;

  TrustEngine({
    required this.roots,
    required this.revocations,
    required this.certGraph,
  });

  /// Builds a [TrustEngine] from the full event [log], folding the revocation
  /// set and certificate graph from it. [roots] carries the out-of-band trusted
  /// org roots.
  factory TrustEngine.fromEvents(
    Iterable<SignedEvent> log, {
    required TrustRootStore roots,
  }) {
    final List<SignedEvent> events = log.toList(growable: false);
    return TrustEngine(
      roots: roots,
      revocations: RevocationSet.fromEvents(events),
      certGraph: OrgCertGraph.fromEvents(events),
    );
  }

  /// Decayed freshness factor in [0, 1] for an item of age [ageMs], using an
  /// exponential half-life decay. Monotonically decreasing in age; equals 1.0
  /// at age 0 and 0.5 at one half-life. Negative ages (clock skew) are clamped
  /// to "now".
  double freshnessFactor(int ageMs) {
    if (ageMs <= 0) return 1.0;
    final double halfLives = ageMs / freshnessHalfLifeMs;
    return math.pow(0.5, halfLives).toDouble();
  }

  /// Computes the profile for [resourceId] by scanning [events].
  ///
  /// [events] should be the relevant event log (the projection passes the full
  /// log). [nowMs] is the evaluation time; defaults to wall-clock now.
  TrustProfile profileForResource(
    String resourceId,
    Iterable<SignedEvent> events, {
    int? nowMs,
  }) {
    final int now = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;

    List<int>? resourceAuthor;
    int? newestRelevantMs;

    // Per-observer latest observation (by lamport) for CONFIRM/DISPUTE dedupe.
    final Map<AuthorKey, _ObservationState> byObserver =
        <AuthorKey, _ObservationState>{};

    for (final SignedEvent e in events) {
      final EventHeader h = e.header;
      switch (h.type) {
        case EventType.EVENT_TYPE_RESOURCE_CREATED:
          final ResourceBody body = _tryResource(e);
          if (body.resourceId == resourceId) {
            resourceAuthor = h.authorPubkey;
            newestRelevantMs =
                _max(newestRelevantMs, h.createdAtMs.toInt());
          }
          break;
        case EventType.EVENT_TYPE_RESOURCE_UPDATED:
          final ResourceUpdateBody body = _tryUpdate(e);
          if (body.resourceId == resourceId) {
            newestRelevantMs =
                _max(newestRelevantMs, h.createdAtMs.toInt());
          }
          break;
        case EventType.EVENT_TYPE_RESOURCE_OBSERVED:
        case EventType.EVENT_TYPE_RESOURCE_CONFIRMED:
        case EventType.EVENT_TYPE_RESOURCE_DISPUTED:
        case EventType.EVENT_TYPE_RESOURCE_USEFUL:
          final ObservationBody body = _tryObservation(e);
          if (body.resourceId != resourceId) break;
          newestRelevantMs = _max(newestRelevantMs, h.createdAtMs.toInt());
          _recordObservation(
            byObserver: byObserver,
            observer: h.authorPubkey,
            lamport: h.lamport.toInt(),
            kind: _kindOf(h.type, body),
          );
          break;
        default:
          break;
      }
    }

    // ---- SOURCE ----
    final List<int> author = resourceAuthor ?? const <int>[];
    final bool authorRevoked =
        author.isNotEmpty && revocations.isRevoked(author);
    final ProvenanceKind kind = author.isEmpty
        ? ProvenanceKind.PROVENANCE_KIND_COMMUNITY
        : certGraph.provenanceOf(
            author,
            roots: roots,
            revocations: revocations,
          );
    // Would the author have been verified were it not revoked? (for the flag)
    final bool wasVerified = authorRevoked &&
        certGraph.provenanceOf(
              author,
              roots: roots,
              revocations: RevocationSet.fromEvents(const <SignedEvent>[]),
            ) ==
            ProvenanceKind.PROVENANCE_KIND_VERIFIED_ORG;
    final Provenance source = Provenance(
      kind: kind,
      revoked: authorRevoked && wasVerified,
    );

    // ---- CORROBORATION ---- (dedupe by observer; exclude the author itself)
    int confirm = 0;
    int dispute = 0;
    int useful = 0;
    int observers = 0;
    final AuthorKey? authorKey =
        author.isEmpty ? null : AuthorKey(author);
    for (final MapEntry<AuthorKey, _ObservationState> entry
        in byObserver.entries) {
      if (authorKey != null && entry.key == authorKey) continue;
      observers++;
      if (entry.value.useful) useful++;
      switch (entry.value.latestVerdict) {
        case _Verdict.confirm:
          confirm++;
          break;
        case _Verdict.dispute:
          dispute++;
          break;
        case _Verdict.none:
          break;
      }
    }
    final Corroboration corroboration = Corroboration(
      confirmCount: confirm,
      disputeCount: dispute,
      usefulCount: useful,
      distinctObservers: observers,
    );

    // ---- FRESHNESS ----
    final int ageMs =
        newestRelevantMs == null ? 0 : math.max(0, now - newestRelevantMs);
    final Freshness freshness = Freshness(
      lastObservedMs: newestRelevantMs,
      ageMs: ageMs,
      decayFactor: freshnessFactor(ageMs),
    );

    // ---- derived band + rank ----
    final ConfidenceBand band =
        _bandFor(source, corroboration, freshness);
    final double rankScore = _rankScore(source, corroboration, freshness);

    return TrustProfile(
      resourceId: resourceId,
      source: source,
      corroboration: corroboration,
      freshness: freshness,
      band: band,
      rankScore: rankScore,
    );
  }

  // --- derivation helpers ---

  ConfidenceBand _bandFor(
    Provenance source,
    Corroboration c,
    Freshness f,
  ) {
    final int net = c.net;
    final bool fresh = f.decayFactor >= 0.5; // within ~one half-life
    final bool verified = source.isVerifiedOrg;

    if (c.distinctObservers == 0 && !verified) {
      return ConfidenceBand.unconfirmed;
    }
    // Heavily disputed drops to low regardless of source.
    if (net < 0) return ConfidenceBand.low;

    if ((verified || net >= 3) && fresh) {
      return ConfidenceBand.high;
    }
    if (verified || net >= 1) {
      return ConfidenceBand.medium;
    }
    return ConfidenceBand.low;
  }

  /// Combines the three dimensions into a single ordering key. Weighting:
  /// verified source and net corroboration dominate, scaled by freshness so
  /// stale items sink; disputes subtract. This is ONLY used for sort order.
  double _rankScore(Provenance source, Corroboration c, Freshness f) {
    final double sourceScore = source.isVerifiedOrg ? 10.0 : 0.0;
    final double corroborationScore = c.confirmCount - 1.5 * c.disputeCount;
    final double base = sourceScore + corroborationScore;
    // Freshness scales the positive evidence so a fresh item outranks an
    // equally-corroborated stale one, but low-confidence items keep a small
    // baseline so they never fall out of the list.
    return base * (0.25 + 0.75 * f.decayFactor);
  }

  // --- folding helpers ---

  void _recordObservation({
    required Map<AuthorKey, _ObservationState> byObserver,
    required List<int> observer,
    required int lamport,
    required _ObsKind kind,
  }) {
    final AuthorKey key = AuthorKey(observer);
    final _ObservationState state =
        byObserver.putIfAbsent(key, () => _ObservationState());

    if (kind == _ObsKind.useful) {
      state.useful = true;
      // "Useful" is independent of the confirm/dispute verdict; it does not
      // change the latest verdict timeline.
      return;
    }

    final _Verdict verdict = switch (kind) {
      _ObsKind.confirm => _Verdict.confirm,
      _ObsKind.dispute => _Verdict.dispute,
      _ObsKind.observed => _Verdict.none,
      _ObsKind.useful => _Verdict.none,
    };

    // Latest verdict by lamport wins (confirm then later dispute => dispute).
    if (verdict != _Verdict.none && lamport >= state.latestVerdictLamport) {
      state.latestVerdict = verdict;
      state.latestVerdictLamport = lamport;
    }
  }

  _ObsKind _kindOf(EventType type, ObservationBody body) {
    switch (type) {
      case EventType.EVENT_TYPE_RESOURCE_CONFIRMED:
        return _ObsKind.confirm;
      case EventType.EVENT_TYPE_RESOURCE_DISPUTED:
        return _ObsKind.dispute;
      case EventType.EVENT_TYPE_RESOURCE_USEFUL:
        return _ObsKind.useful;
      case EventType.EVENT_TYPE_RESOURCE_OBSERVED:
        // Fall back to the body kind for a generic observation.
        switch (body.kind) {
          case ObservationBody_Kind.KIND_CONFIRMED:
            return _ObsKind.confirm;
          case ObservationBody_Kind.KIND_DISPUTED:
            return _ObsKind.dispute;
          case ObservationBody_Kind.KIND_USEFUL:
            return _ObsKind.useful;
          default:
            return _ObsKind.observed;
        }
      default:
        return _ObsKind.observed;
    }
  }

  ResourceBody _tryResource(SignedEvent e) {
    try {
      return ResourceBody.fromBuffer(e.body);
    } catch (_) {
      return ResourceBody();
    }
  }

  ResourceUpdateBody _tryUpdate(SignedEvent e) {
    try {
      return ResourceUpdateBody.fromBuffer(e.body);
    } catch (_) {
      return ResourceUpdateBody();
    }
  }

  ObservationBody _tryObservation(SignedEvent e) {
    try {
      return ObservationBody.fromBuffer(e.body);
    } catch (_) {
      return ObservationBody();
    }
  }

  static int _max(int? a, int b) => a == null ? b : math.max(a, b);
}

enum _ObsKind { observed, confirm, dispute, useful }

enum _Verdict { none, confirm, dispute }

/// Mutable per-observer accumulator used while folding observations.
class _ObservationState {
  _Verdict latestVerdict = _Verdict.none;
  int latestVerdictLamport = -1;
  bool useful = false;
}
