import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/envelope.dart';
import '../../models/network.dart';
import 'mesh_transport.dart';

/// Where a [SimulatedTransport] cuts the link during its next send.
enum SimulatedDrop {
  /// Before the far side gets anything.
  beforeArrival,

  /// After the far side stored the batch, before its confirmation comes
  /// back: the phone can't tell, so it sends again and the far side must
  /// drop the copy.
  beforeAck,
}

/// Plays any link for the demo and for tests: the far side takes a batch
/// after [latency], and the link can go up and down at any moment.
class SimulatedTransport extends MeshTransport {
  SimulatedTransport(
    this.kind, {
    bool up = false,
    int peers = 0,
    bool reachesCloud = false,
    this.latency = const Duration(milliseconds: 300),
    this.maxBatch = 8,
    bool Function(Envelope e)? accepts,
  })  : _accepts = accepts,
        _status = ValueNotifier(LinkStatus(
          kind: kind,
          up: up,
          peers: peers,
          reachesCloud: reachesCloud,
        ));

  @override
  final LinkKind kind;

  /// How long the far side takes to confirm a batch.
  Duration latency;

  @override
  final int maxBatch;

  final bool Function(Envelope e)? _accepts;
  final ValueNotifier<LinkStatus> _status;
  final _received = StreamController<Envelope>.broadcast();

  /// Every envelope that reached the far side, copies included, in the
  /// order they arrived.
  final arrivals = <Envelope>[];

  /// Ids the far side stored once each: what a receiver that drops
  /// duplicates by id ends up with.
  final stored = <String>{};

  /// How many batches [send] was asked to carry.
  int sends = 0;

  /// Cuts the link during the next send.
  SimulatedDrop? dropNext;

  /// Changes every time the link goes down, so a send in progress can
  /// tell it was cut.
  int _generation = 0;

  @override
  ValueListenable<LinkStatus> get status => _status;

  bool get up => _status.value.up;

  @override
  bool accepts(Envelope envelope) => _accepts?.call(envelope) ?? true;

  /// Brings the link up or down; going down cuts any send in progress.
  void set({bool? up, int? peers, bool? reachesCloud}) {
    final s = _status.value;
    final nowUp = up ?? s.up;
    if (s.up && !nowUp) _generation++;
    _status.value = LinkStatus(
      kind: kind,
      up: nowUp,
      peers: peers ?? s.peers,
      reachesCloud: reachesCloud ?? s.reachesCloud,
      available: s.available,
    );
  }

  @override
  Future<TransportAck> send(List<Envelope> batch) async {
    sends++;
    if (!up) throw const LinkDropped('down');
    final generation = _generation;
    final drop = dropNext;
    dropNext = null;

    await Future<void>.delayed(latency ~/ 2);
    if (generation != _generation || drop == SimulatedDrop.beforeArrival) {
      throw const LinkDropped('cut before arrival');
    }
    arrivals.addAll(batch);
    stored.addAll(batch.map((e) => e.id));

    await Future<void>.delayed(latency - latency ~/ 2);
    if (generation != _generation || drop == SimulatedDrop.beforeAck) {
      throw const LinkDropped('cut before the confirmation');
    }
    return TransportAck.all(batch);
  }

  /// Plays another phone sending [envelope] to this one.
  void deliver(Envelope envelope) => _received.add(envelope);

  @override
  Stream<Envelope> get received => _received.stream;

  @override
  void dispose() {
    _generation++;
    _received.close();
    _status.dispose();
  }
}
