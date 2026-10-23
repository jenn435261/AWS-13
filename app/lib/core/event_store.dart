import 'dart:typed_data';

import '../db/event_dao.dart';
import '../gen/resilience/v1/event.pb.dart';
import 'event_factory.dart';
import 'lamport_clock.dart';

/// Outcome of applying an event to the store.
enum ApplyStatus {
  /// The event was valid and newly persisted.
  applied,

  /// An event with the same content hash was already present; nothing changed.
  duplicate,

  /// The event failed verification (bad signature or hash mismatch) and was
  /// NOT persisted.
  invalid,
}

/// Result of [EventStore.apply].
class ApplyResult {
  final ApplyStatus status;

  /// The event's content id (`event_id`), when it could be determined.
  final Uint8List? eventId;

  const ApplyResult(this.status, {this.eventId});

  bool get isApplied => status == ApplyStatus.applied;
  bool get isDuplicate => status == ApplyStatus.duplicate;
  bool get isInvalid => status == ApplyStatus.invalid;

  @override
  String toString() => 'ApplyResult($status)';
}

/// High-level store that wraps the [EventDao] with verification and clock
/// maintenance. This is the reconciliation primitive the sync engine builds on.
///
/// `apply` is the single ingestion path for *every* event — whether created
/// locally or received from a peer. It:
///
/// 1. Verifies the event (Ed25519 signature + BLAKE2b-256 content hash +
///    header sanity) via [EventFactory.verifyEvent]. Invalid events are
///    rejected and never stored.
/// 2. Observes the event's Lamport timestamp so our clock stays ahead of
///    everything we have witnessed (`observe`).
/// 3. Persists the event, de-duplicating by content hash.
///
/// Because identity is a content hash and ingestion is idempotent, applying the
/// same event any number of times converges to the same state — the property
/// that lets the gossip DAG reconcile correctly regardless of delivery order or
/// wrong device wall-clocks.
class EventStore {
  final EventDao _dao;
  final EventFactory _factory;
  final LamportClock _clock;

  EventStore({
    required EventDao dao,
    EventFactory? factory,
    LamportClock? clock,
  })  : _dao = dao,
        _factory = factory ?? EventFactory(),
        _clock = clock ?? LamportClock();

  /// The Lamport clock advanced by this store (shared with local creation).
  LamportClock get clock => _clock;

  EventDao get dao => _dao;

  /// Verifies and applies a single [event].
  ///
  /// Returns [ApplyStatus.invalid] without storing if verification fails;
  /// [ApplyStatus.duplicate] if the content hash is already stored;
  /// [ApplyStatus.applied] if it was newly persisted.
  Future<ApplyResult> apply(SignedEvent event) async {
    final bool ok = await _factory.verifyEvent(event);
    if (!ok) {
      return const ApplyResult(ApplyStatus.invalid);
    }

    final Uint8List id = Uint8List.fromList(event.header.eventId);

    // Keep the clock ahead of everything we've seen, even if it's a duplicate
    // (so observing a re-delivered event is still safe and idempotent).
    _clock.observe(event.header.lamport);

    final bool inserted = await _dao.insertEvent(event, valid: true);
    return ApplyResult(
      inserted ? ApplyStatus.applied : ApplyStatus.duplicate,
      eventId: id,
    );
  }

  /// Applies a batch of events, returning a result per event in input order.
  Future<List<ApplyResult>> applyAll(Iterable<SignedEvent> batch) async {
    final List<ApplyResult> out = <ApplyResult>[];
    for (final e in batch) {
      out.add(await apply(e));
    }
    return out;
  }

  /// Fetches a stored event by id.
  Future<SignedEvent?> get(List<int> eventId) => _dao.getEvent(eventId);

  /// Our per-author high-water marks (author pubkey -> max lamport held).
  /// This is the digest we advertise to peers.
  Future<Map<AuthorKey, int>> highWaterByAuthor() =>
      _dao.highWaterByAuthor();

  /// Computes the events we hold that a peer is missing, given the peer's
  /// per-author high-water digest [peerDigest] (author pubkey -> the highest
  /// lamport the peer has for that author).
  ///
  /// For each author we know about, we return every event whose lamport exceeds
  /// the peer's watermark for that author. Authors the peer has never seen
  /// (absent from [peerDigest]) are treated as watermark 0, i.e. the peer gets
  /// that author's entire log.
  ///
  /// The returned list is ordered by (author, lamport, event_id) so batches are
  /// deterministic and causally-friendly (lower lamports first within an
  /// author).
  Future<List<SignedEvent>> missingFrom(Map<AuthorKey, int> peerDigest) async {
    final Map<AuthorKey, int> ours = await _dao.highWaterByAuthor();

    final List<SignedEvent> missing = <SignedEvent>[];

    // Deterministic author iteration order: sort authors by their bytes.
    final List<AuthorKey> authors = ours.keys.toList()
      ..sort(_compareAuthors);

    for (final AuthorKey author in authors) {
      final int peerHw = peerDigest[author] ?? 0;
      final int ourHw = ours[author] ?? 0;
      if (ourHw <= peerHw) {
        // Peer is at or ahead of us for this author; nothing to send.
        continue;
      }
      final List<SignedEvent> events =
          await _dao.eventsByAuthorFrom(author.bytes, peerHw);
      missing.addAll(events);
    }
    return missing;
  }

  static int _compareAuthors(AuthorKey a, AuthorKey b) {
    final Uint8List ab = a.bytes;
    final Uint8List bb = b.bytes;
    final int n = ab.length < bb.length ? ab.length : bb.length;
    for (int i = 0; i < n; i++) {
      final int d = ab[i] - bb[i];
      if (d != 0) return d;
    }
    return ab.length - bb.length;
  }
}
