import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/envelope.dart';
import '../../models/network.dart';
import 'location_policy.dart';
import 'mesh_transport.dart';
import 'router.dart';

/// An envelope a route confirmed (or refused for good).
class Delivery {
  const Delivery(this.envelope, this.via, {this.accepted = true});

  final Envelope envelope;
  final LinkKind via;

  /// False when the far side refused it for good.
  final bool accepted;
}

/// Store and forward: every message and event waits here until a route
/// confirms it.
///
///  * Nothing is lost: an item leaves the outbox only on a confirmation,
///    or when the person takes it back before it left.
///  * Nothing is sent twice by this phone: one batch is out at a time, and
///    an item a route confirmed is never sent again. When a link drops
///    mid-send the phone can't know whether it arrived, so it sends again;
///    receivers drop the copy by id (the Node does, by event id).
///  * Order: urgent items first; within the same priority, in the order
///    they were queued; and never before an earlier item about the same
///    request, resource or chat.
///  * When a route comes back, waiting items go at once.
class Outbox {
  Outbox({
    required this.router,
    required this.policy,
    this.sendTimeout = const Duration(seconds: 30),
    this.retryDelay = const Duration(seconds: 5),
  }) {
    for (final t in router.transports) {
      _wasUp[t] = t.status.value.up;
    }
    router.changes.addListener(_onLinksChanged);
  }

  final TransportRouter router;
  final LocationPolicy policy;

  /// A send with no answer by then counts as dropped.
  final Duration sendTimeout;

  /// How long a route that just failed is left alone, unless it comes
  /// back up sooner.
  final Duration retryDelay;

  final _waiting = <Envelope>[];
  final _inFlight = <String>{};

  /// Ids confirmed, refused or dropped by the privacy rule: never sent again.
  final _finished = <String>{};
  final _held = ValueNotifier(0);
  final _delivered = StreamController<Delivery>.broadcast();
  final _resting = <MeshTransport, DateTime>{};
  final _wasUp = <MeshTransport, bool>{};
  final _lastAck = <LinkKind, DateTime>{};
  Timer? _retry;
  bool _pumping = false;
  bool _disposed = false;

  /// How many items wait on this phone.
  ValueListenable<int> get held => _held;

  /// Items as routes confirm them, each once.
  Stream<Delivery> get delivered => _delivered.stream;

  /// What waits, in the order it was queued.
  List<Envelope> get waiting => List.unmodifiable(_waiting);

  /// When each kind of link last confirmed something.
  Map<LinkKind, DateTime> get lastAcks => Map.unmodifiable(_lastAck);

  bool isWaiting(String id) => _waiting.any((e) => e.id == id);

  bool isInFlight(String id) => _inFlight.contains(id);

  /// Queues [envelope]. Returns false for a copy of one already queued or
  /// sent, and for one the privacy rule keeps on the phone.
  bool add(Envelope envelope) {
    if (_disposed) return false;
    if (_finished.contains(envelope.id) || isWaiting(envelope.id)) return false;
    final e = policy.admit(envelope);
    if (e == null) return false;
    final key = e.replaceKey;
    if (key != null) {
      _waiting.removeWhere((x) => x.replaceKey == key && !_inFlight.contains(x.id));
    }
    _waiting.add(e);
    _changed();
    _pump();
    return true;
  }

  /// Takes back an item that has not left yet. False once it is on its way.
  bool withdraw(String id) {
    if (_inFlight.contains(id)) return false;
    final before = _waiting.length;
    _waiting.removeWhere((e) => e.id == id);
    if (_waiting.length == before) return false;
    _changed();
    return true;
  }

  /// Drops waiting items that match [test] (not one already on its way).
  int purge(bool Function(Envelope e) test) {
    final drop = [
      for (final e in _waiting)
        if (test(e) && !_inFlight.contains(e.id)) e,
    ];
    for (final e in drop) {
      _waiting.remove(e);
      _finished.add(e.id);
    }
    if (drop.isNotEmpty) _changed();
    return drop.length;
  }

  /// Forgets everything waiting, for a full erase.
  void clear() {
    _waiting.removeWhere((e) => !_inFlight.contains(e.id));
    _changed();
  }

  void _changed() {
    if (!_disposed) _held.value = _waiting.length;
  }

  void _onLinksChanged() {
    if (_disposed) return;
    for (final t in router.transports) {
      final up = t.status.value.up;
      // A link that comes back gets another chance at once.
      if (up && _wasUp[t] != true) _resting.remove(t);
      _wasUp[t] = up;
    }
    _pump();
  }

  /// Sends batches until nothing waiting can go anywhere.
  Future<void> _pump() async {
    if (_pumping || _disposed) return;
    _pumping = true;
    try {
      while (!_disposed) {
        final next = _next();
        if (next == null) break;
        await _send(next.$1, next.$2);
      }
    } finally {
      _pumping = false;
    }
    _scheduleRetry();
  }

  /// The next route and batch: urgent first, then queue order, never ahead
  /// of an earlier item about the same subject.
  (MeshTransport, List<Envelope>)? _next() {
    final now = DateTime.now();
    _resting.removeWhere((_, until) => !until.isAfter(now));
    final skip = _resting.keys.toSet();

    // A live position that waited past the end of its delivery never goes.
    final stale = [for (final e in _waiting) if (!policy.maySend(e)) e];
    for (final e in stale) {
      _waiting.remove(e);
      _finished.add(e.id);
    }
    if (stale.isNotEmpty) _changed();

    final index = {for (final (i, e) in _waiting.indexed) e.id: i};
    final bySubject = <String, List<int>>{};
    for (final (i, e) in _waiting.indexed) {
      (bySubject[e.subject] ??= []).add(i);
    }
    final order = [
      for (final p in SendPriority.values)
        for (final e in _waiting)
          if (e.priority == p) e,
    ];

    bool ready(Envelope e, Set<String> going) {
      final i = index[e.id]!;
      for (final j in bySubject[e.subject]!) {
        if (j >= i) break;
        if (!going.contains(_waiting[j].id)) return false;
      }
      return true;
    }

    for (final first in order) {
      if (!ready(first, const {})) continue;
      final routes = router.routesFor(first, skip: skip);
      if (routes.isEmpty) continue;
      final route = routes.first;
      final batch = [first];
      final going = {first.id};
      for (final e in order) {
        if (batch.length >= route.maxBatch) break;
        if (going.contains(e.id) || !route.accepts(e) || !ready(e, going)) continue;
        // Only items whose own best route is this one, so a cloud-bound
        // batch doesn't drag along something meant for elsewhere.
        if (router.routesFor(e, skip: skip).firstOrNull != route) continue;
        batch.add(e);
        going.add(e.id);
      }
      return (route, batch);
    }
    return null;
  }

  Future<void> _send(MeshTransport route, List<Envelope> batch) async {
    final ids = [for (final e in batch) e.id];
    _inFlight.addAll(ids);
    try {
      final ack = await route.send(batch).timeout(sendTimeout);
      if (_disposed) return;
      var took = false;
      for (final e in batch) {
        final applied = ack.applied.contains(e.id);
        if (!applied && !ack.rejected.contains(e.id)) continue;
        took = true;
        _waiting.removeWhere((x) => x.id == e.id);
        _finished.add(e.id);
        _delivered.add(Delivery(e, route.kind, accepted: applied));
      }
      if (ack.applied.isNotEmpty) _lastAck[route.kind] = DateTime.now();
      if (!took) _rest(route);
    } on Object {
      // Dropped mid-send or no answer: everything stays, in its place.
      if (!_disposed) _rest(route);
    } finally {
      _inFlight.removeAll(ids);
      _changed();
    }
  }

  void _rest(MeshTransport route) =>
      _resting[route] = DateTime.now().add(retryDelay);

  /// Wakes up when a resting route may be tried again, if anything waits.
  void _scheduleRetry() {
    _retry?.cancel();
    _retry = null;
    if (_disposed || _waiting.isEmpty || _resting.isEmpty) return;
    final soonest = _resting.values.reduce((a, b) => a.isBefore(b) ? a : b);
    final wait = soonest.difference(DateTime.now());
    _retry = Timer(wait.isNegative ? Duration.zero : wait, _pump);
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    router.changes.removeListener(_onLinksChanged);
    _delivered.close();
    _held.dispose();
  }
}
