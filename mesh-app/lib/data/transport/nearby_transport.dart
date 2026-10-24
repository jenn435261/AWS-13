import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/envelope.dart';
import '../../models/network.dart';
import '../wire/event_codec.dart';
import '../wire/proto.dart';
import 'mesh_transport.dart';
import 'radio_link.dart';

/// `resilience.v1.SyncFrame` holding an `EventBatch`: what phones hand
/// each other over Bluetooth or Wi-Fi.
class SyncFrameCodec {
  const SyncFrameCodec._();

  static Uint8List batch(List<WireEvent> events) {
    final batch = (ProtoWriter()..repeated(1, [for (final e in events) e.toBytes()])).done();
    return (ProtoWriter()..message(4, batch)).done();
  }

  /// The events in a batch frame; empty for any other frame.
  static List<WireEvent> events(Uint8List frame) {
    try {
      final batch = ProtoReader(frame).message(4);
      if (batch == null) return const [];
      return [for (final e in batch.repeated(1)) WireEvent.fromBytes(e)];
    } on ProtoFormatException {
      return const [];
    }
  }
}

/// Phones nearby, over Bluetooth or Wi-Fi, through [RadioLink]. Each phone
/// keeps what it gets and passes it on when it meets others.
class NearbyTransport extends MeshTransport {
  NearbyTransport({required this.kind, required this.link, required this.codec})
      : assert(kind == LinkKind.bluetooth || kind == LinkKind.wifi) {
    link.state.addListener(_sync);
    _sync();
    _sub = link.frames.listen(_onFrame);
  }

  @override
  final LinkKind kind;
  final RadioLink link;
  final EventCodec codec;

  late final _status = ValueNotifier(LinkStatus(kind: kind, up: false));
  final _received = StreamController<Envelope>.broadcast();
  late final StreamSubscription<Uint8List> _sub;

  @override
  ValueListenable<LinkStatus> get status => _status;

  @override
  Stream<Envelope> get received => _received.stream;

  @override
  int get maxBatch => kind == LinkKind.wifi ? 50 : 10;

  /// Other phones relay what they get, so private items wait for
  /// end-to-end encryption here too.
  @override
  bool accepts(Envelope envelope) => !envelope.needsEndToEnd && codec.canEncode(envelope);

  void _sync() {
    final s = link.state.value;
    _status.value = LinkStatus(
      kind: kind,
      up: s.available && s.connected && s.peers > 0,
      peers: s.connected ? s.peers : 0,
      available: s.available,
    );
  }

  @override
  Future<void> start() => link.start();

  @override
  Future<TransportAck> send(List<Envelope> batch) async {
    final events = await Future.wait(batch.map(codec.encode));
    final frame = SyncFrameCodec.batch(events);
    if (frame.length > link.maxFrameBytes) {
      throw const LinkDropped('batch too large for this link');
    }
    try {
      await link.send(frame);
    } on Object catch (err) {
      throw LinkDropped('$err');
    }
    return TransportAck.all(batch);
  }

  Future<void> _onFrame(Uint8List frame) async {
    for (final event in SyncFrameCodec.events(frame)) {
      if (!await event.verify()) continue;
      final envelope = EventCodec.decode(event);
      if (envelope != null && !_received.isClosed) _received.add(envelope);
    }
  }

  @override
  void dispose() {
    link.state.removeListener(_sync);
    _sub.cancel();
    _received.close();
    _status.dispose();
    link.dispose();
  }
}
