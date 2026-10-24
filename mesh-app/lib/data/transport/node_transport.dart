import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/envelope.dart';
import '../../models/network.dart';
import '../node_client.dart';
import '../wire/event_codec.dart';
import 'mesh_transport.dart';

/// A Resilience Node on local Wi-Fi, through its real HTTP API.
///
/// The link is up while `/healthz` answers. Pushes are batched; the Node's
/// ack names each event it stored, so the outbox knows exactly what left.
/// [sync] also pulls what other phones left on the Node.
class NodeTransport extends MeshTransport {
  NodeTransport({
    required this.client,
    required this.codec,
    this.probeEvery = const Duration(seconds: 15),
  });

  final NodeClient client;
  final EventCodec codec;

  /// How often [start] checks the Node is still there and pulls news.
  final Duration probeEvery;

  final _status = ValueNotifier(const LinkStatus(kind: LinkKind.node, up: false));
  final _received = StreamController<Envelope>.broadcast();

  /// Highest lamport seen per author (public key hex), for pulls.
  final _watermarks = <String, int>{};
  final _seen = <String>{};
  Timer? _timer;
  bool _disposed = false;

  @override
  LinkKind get kind => LinkKind.node;

  @override
  ValueListenable<LinkStatus> get status => _status;

  @override
  int get maxBatch => 50;

  @override
  bool accepts(Envelope envelope) =>
      !envelope.needsEndToEnd && codec.canEncode(envelope);

  @override
  Stream<Envelope> get received => _received.stream;

  @override
  Future<void> start() async {
    await sync();
    _timer ??= Timer.periodic(probeEvery, (_) => sync());
  }

  void _setUp(bool up) {
    if (_disposed || _status.value.up == up) return;
    _status.value = LinkStatus(kind: LinkKind.node, up: up, lastAck: _status.value.lastAck);
  }

  /// Checks the Node is there.
  Future<bool> probe() async {
    final ok = await client.healthy();
    _setUp(ok);
    return ok;
  }

  @override
  Future<TransportAck> send(List<Envelope> batch) async {
    if (!_status.value.up) throw const LinkDropped('no node');
    final events = await Future.wait(batch.map(codec.encode));
    final NodeAck ack;
    try {
      ack = await client.push(events);
    } on Object catch (e) {
      // Unreachable or broken: assume nothing arrived, and look again.
      _setUp(false);
      throw LinkDropped('$e');
    }
    return TransportAck(
      applied: {
        for (final (i, e) in batch.indexed)
          if (ack.applied.contains(events[i].idHex)) e.id,
      },
      rejected: {
        for (final (i, e) in batch.indexed)
          if (ack.rejected.contains(events[i].idHex)) e.id,
      },
    );
  }

  /// Checks the Node, then pulls events this phone hasn't seen. Only
  /// events whose id and signature check out are passed on.
  Future<void> sync() async {
    if (_disposed || !await probe()) return;
    try {
      final events = await client.pull(from: _watermarks, limit: 500);
      final mine = hexOf(codec.identity.publicKey);
      for (final event in events) {
        if (!_seen.add(event.idHex)) continue;
        final author = hexOf(event.author);
        if (event.lamport > (_watermarks[author] ?? 0)) _watermarks[author] = event.lamport;
        if (author == mine || !await event.verify()) continue;
        final envelope = EventCodec.decode(event);
        if (envelope != null && !_disposed) _received.add(envelope);
      }
    } on Object {
      // A failed pull is retried on the next probe.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _received.close();
    _status.dispose();
    client.close();
  }
}
