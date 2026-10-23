import 'dart:async';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';

import '../core/event_store.dart';
import '../db/event_dao.dart';
import '../gen/resilience/v1/event.pb.dart';
import '../gen/resilience/v1/sync.pb.dart';
import '../transport/transport.dart';
import 'bloom.dart';
import 'frame_codec.dart';

/// Counts describing one reconciliation run.
class SyncReport {
  /// Number of [SyncFrame]s sent on this session.
  final int sent;

  /// Number of [SyncFrame]s received on this session.
  final int received;

  /// Number of events newly applied to the local store from the peer.
  final int applied;

  /// Number of events the peer sent us that we rejected as invalid.
  final int rejected;

  const SyncReport({
    required this.sent,
    required this.received,
    required this.applied,
    required this.rejected,
  });

  @override
  String toString() =>
      'SyncReport(sent: $sent, received: $received, applied: $applied, '
      'rejected: $rejected)';
}

/// Runs the gossip reconciliation protocol with one peer to convergence.
///
/// Given a local [EventStore] and an open [PeerSession], a [SyncEngine]
/// exchanges [SyncFrame]s so that, after the run settles, BOTH sides hold the
/// union of all valid events each side started with. The protocol:
///
/// 1. On open: send `Hello`, then a `HaveDigest` carrying our per-author
///    high-water marks plus a Bloom filter of all our event ids.
/// 2. On a peer `HaveDigest`: compute what the peer lacks via
///    `store.missingFrom(peerDigest)` and push it as chunked `EventBatch`es
///    (<= [maxBatch] events each, `more` set on all but the last). Also compute
///    what WE lack — for every author the peer advertises at a higher
///    high-water than ours, ask for the tail with `WantList.from` — and send a
///    `WantList`.
/// 3. On a peer `WantList`: answer the requested ids and author-from ranges as
///    `EventBatch`es.
/// 4. On a peer `EventBatch`: `store.applyAll(...)` and reply with
///    `Ack{applied, rejected}` where `rejected` lists events whose apply status
///    was `invalid` (bad signature / tampering). Invalid events are never
///    stored.
///
/// ## Store-carry-forward (spec §17)
///
/// The engine syncs *whatever is in the local store* — it never distinguishes
/// "events I authored" from "events I relayed". So if node C received events
/// from A and B, then later meets D, C forwards A's and B's events to D exactly
/// as if they were its own. This works because events are content-addressed
/// (their id is a hash of their bytes) and [EventStore.apply] is idempotent:
/// re-delivering an event any number of times, over any path, converges to the
/// same state. Carrying C -> D therefore needs no special case.
///
/// The engine is idempotent and safe to run repeatedly; a second
/// [runUntilIdle] after no changes transfers nothing.
class SyncEngine {
  final EventStore store;
  final PeerSession session;

  /// Max events per [EventBatch]. The spec requires <= 256.
  final int maxBatch;

  /// Bits per item for the advertised Bloom filter.
  final int bloomBitsPerItem;

  /// How long the engine waits for additional frames before declaring the
  /// session quiescent (converged) in [runUntilIdle].
  final Duration idleTimeout;

  final FrameDecoder _decoder = FrameDecoder();
  StreamSubscription<Uint8List>? _sub;

  int _sent = 0;
  int _received = 0;
  int _applied = 0;
  int _rejected = 0;

  // Resets each time a frame moves, so the idle detector knows there is still
  // activity in flight.
  Completer<void>? _idleCompleter;
  Timer? _idleTimer;
  bool _running = false;

  SyncEngine({
    required this.store,
    required this.session,
    this.maxBatch = 256,
    this.bloomBitsPerItem = 10,
    this.idleTimeout = const Duration(milliseconds: 60),
  }) : assert(maxBatch > 0 && maxBatch <= 256,
            'maxBatch must be in 1..256');

  /// Runs reconciliation until the session goes quiet (no frames exchanged for
  /// [idleTimeout]) and returns the tallied [SyncReport].
  ///
  /// Both peers should call this concurrently; the method opens the protocol by
  /// sending Hello + HaveDigest and then drives it reactively off incoming
  /// frames until convergence.
  Future<SyncReport> runUntilIdle() async {
    if (_running) {
      throw StateError('SyncEngine is already running');
    }
    _running = true;
    _idleCompleter = Completer<void>();

    _sub = session.incoming.listen(
      _onBytes,
      onError: (_) => _settleIdle(),
      onDone: _settleIdle,
    );

    // Kick off the handshake.
    await _sendHello();
    await _sendHaveDigest();

    _bumpIdle();

    await _idleCompleter!.future;

    _idleTimer?.cancel();
    await _sub?.cancel();
    _running = false;

    return SyncReport(
      sent: _sent,
      received: _received,
      applied: _applied,
      rejected: _rejected,
    );
  }

  // --- Idle detection ------------------------------------------------------

  /// Restart the quiescence timer because activity just happened.
  void _bumpIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, _settleIdle);
  }

  void _settleIdle() {
    if (_idleCompleter != null && !_idleCompleter!.isCompleted) {
      _idleCompleter!.complete();
    }
  }

  // --- Frame plumbing ------------------------------------------------------

  Future<void> _onBytes(Uint8List bytes) async {
    final List<SyncFrame> frames = _decoder.addChunk(bytes);
    for (final SyncFrame frame in frames) {
      _received++;
      _bumpIdle();
      await _handle(frame);
      _bumpIdle();
    }
  }

  Future<void> _send(SyncFrame frame) async {
    if (!session.isOpen) return;
    _sent++;
    await session.send(FrameCodec.encodeFrame(frame));
    _bumpIdle();
  }

  Future<void> _handle(SyncFrame frame) async {
    switch (frame.whichFrame()) {
      case SyncFrame_Frame.hello:
        // Nothing required; the HaveDigest drives the diff.
        break;
      case SyncFrame_Frame.have:
        await _onHaveDigest(frame.have);
        break;
      case SyncFrame_Frame.want:
        await _onWantList(frame.want);
        break;
      case SyncFrame_Frame.batch:
        await _onEventBatch(frame.batch);
        break;
      case SyncFrame_Frame.ack:
        // Acks are informational for this engine; counts already tallied.
        break;
      case SyncFrame_Frame.mesh:
      case SyncFrame_Frame.notSet:
        break;
    }
  }

  // --- Outbound handshake --------------------------------------------------

  Future<void> _sendHello() async {
    final Map<AuthorKey, int> hw = await store.highWaterByAuthor();
    int maxHw = 0;
    for (final int v in hw.values) {
      if (v > maxHw) maxHw = v;
    }
    final Hello hello = Hello(
      lamportHighWater: Int64(maxHw),
      knownAuthors: hw.keys.map((k) => k.bytes).toList(),
    );
    await _send(SyncFrame(hello: hello));
  }

  Future<void> _sendHaveDigest() async {
    final Map<AuthorKey, int> hw = await store.highWaterByAuthor();
    final List<Uint8List> ids = await store.dao.allEventIds();

    final BloomFilter bloom = BloomFilter.build(
      ids,
      bitsPerItem: bloomBitsPerItem,
    );

    final HaveDigest digest = HaveDigest(
      authors: hw.entries.map((e) => HaveDigest_AuthorHW(
            authorPubkey: e.key.bytes,
            highWater: Int64(e.value),
          )),
      bloom: bloom.bytes,
      bloomHashes: bloom.numHashes,
      bloomBits: bloom.numBits,
    );
    await _send(SyncFrame(have: digest));
  }

  // --- Inbound handlers ----------------------------------------------------

  Future<void> _onHaveDigest(HaveDigest digest) async {
    // Reconstruct the peer's per-author watermark map.
    final Map<AuthorKey, int> peerDigest = <AuthorKey, int>{};
    for (final HaveDigest_AuthorHW a in digest.authors) {
      peerDigest[AuthorKey(a.authorPubkey)] = a.highWater.toInt();
    }

    // 1. Push what the peer is missing.
    final List<SignedEvent> missing = await store.missingFrom(peerDigest);
    await _sendBatches(missing);

    // 2. Ask for what we are missing: for each author the peer advertises above
    //    our own watermark (including authors we have never seen), request the
    //    tail from our watermark.
    final Map<AuthorKey, int> ours = await store.highWaterByAuthor();
    final List<WantList_AuthorFrom> wants = <WantList_AuthorFrom>[];
    for (final HaveDigest_AuthorHW a in digest.authors) {
      final AuthorKey key = AuthorKey(a.authorPubkey);
      final int peerHw = a.highWater.toInt();
      final int ourHw = ours[key] ?? 0;
      if (peerHw > ourHw) {
        wants.add(WantList_AuthorFrom(
          authorPubkey: a.authorPubkey,
          fromLamport: Int64(ourHw),
        ));
      }
    }
    if (wants.isNotEmpty) {
      await _send(SyncFrame(want: WantList(from: wants)));
    }
  }

  Future<void> _onWantList(WantList want) async {
    final List<SignedEvent> out = <SignedEvent>[];
    final Set<String> seen = <String>{};

    // Explicit ids.
    for (final List<int> id in want.eventIds) {
      final SignedEvent? e = await store.get(id);
      if (e != null && seen.add(_idKey(e))) {
        out.add(e);
      }
    }

    // Author-from ranges.
    for (final WantList_AuthorFrom from in want.from) {
      final List<SignedEvent> events = await store.dao.eventsByAuthorFrom(
        from.authorPubkey,
        from.fromLamport.toInt(),
      );
      for (final SignedEvent e in events) {
        if (seen.add(_idKey(e))) out.add(e);
      }
    }

    await _sendBatches(out);
  }

  Future<void> _onEventBatch(EventBatch batch) async {
    final List<ApplyResult> results = await store.applyAll(batch.events);

    final Ack ack = Ack();
    for (int i = 0; i < results.length; i++) {
      final ApplyResult r = results[i];
      final List<int> id = batch.events[i].header.eventId;
      if (r.isInvalid) {
        _rejected++;
        ack.rejected.add(id);
      } else {
        if (r.isApplied) _applied++;
        ack.applied.add(id);
      }
    }
    await _send(SyncFrame(ack: ack));
  }

  // --- Helpers -------------------------------------------------------------

  /// Sends [events] as one or more [EventBatch]es of at most [maxBatch] each,
  /// setting `more` on every batch except the last. Sends nothing when empty.
  Future<void> _sendBatches(List<SignedEvent> events) async {
    if (events.isEmpty) return;
    for (int start = 0; start < events.length; start += maxBatch) {
      final int end =
          (start + maxBatch < events.length) ? start + maxBatch : events.length;
      final bool more = end < events.length;
      final EventBatch batch = EventBatch(
        events: events.sublist(start, end),
        more: more,
      );
      await _send(SyncFrame(batch: batch));
    }
  }

  static String _idKey(SignedEvent e) {
    final List<int> id = e.header.eventId;
    final StringBuffer sb = StringBuffer();
    for (final int b in id) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
