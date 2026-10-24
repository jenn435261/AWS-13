import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../models/envelope.dart';
import '../../models/network.dart';
import '../wire/event_codec.dart';
import '../wire/proto.dart';
import 'mesh_transport.dart';
import 'radio_link.dart';

/// `resilience.v1.MeshPacket`: one LoRa packet. Relays see the priority,
/// hop count and an opaque id, never who it is for. An event too big for
/// one packet is split and put back together on the far side.
class MeshPacketCodec {
  const MeshPacketCodec._();

  /// Room taken by the packet's own fields.
  static const _overhead = 32;

  static List<Uint8List> split(
    WireEvent event, {
    required int maxFrameBytes,
    required int priority,
    int hops = 3,
  }) {
    final payload = event.toBytes();
    final chunk = maxFrameBytes - _overhead;
    final total = (payload.length / chunk).ceil().clamp(1, 1 << 16);
    return [
      for (var i = 0; i < total; i++)
        (ProtoWriter()
              ..bytes(1, event.eventId.sublist(0, 8))
              ..uint(2, priority)
              ..uint(3, hops)
              ..bytes(5, payload.sublist(i * chunk, ((i + 1) * chunk).clamp(0, payload.length)))
              ..uint(6, i)
              ..uint(7, total))
            .done(),
    ];
  }
}

/// Puts split events back together, in any arrival order.
class MeshPacketAssembler {
  final _parts = <String, Map<int, Uint8List>>{};

  /// Returns the whole event once its last piece arrives, otherwise null.
  WireEvent? add(Uint8List frame) {
    try {
      final p = ProtoReader(frame);
      final id = hexOf(p.bytes(1));
      final total = p.uint(7).clamp(1, 1 << 16);
      final parts = _parts[id] ??= {};
      parts[p.uint(6)] = p.bytes(5);
      if (parts.length < total) return null;
      _parts.remove(id);
      final bytes = BytesBuilder();
      for (var i = 0; i < total; i++) {
        final part = parts[i];
        if (part == null) return null;
        bytes.add(part);
      }
      return WireEvent.fromBytes(bytes.toBytes());
    } on ProtoFormatException {
      return null;
    }
  }
}

/// A LoRa radio on the Meshtastic mesh, through [RadioLink].
///
/// LoRa airtime is scarce, so it carries urgent and normal items only;
/// votes and the like wait for a faster link.
class LoraTransport extends MeshTransport {
  LoraTransport({required this.radio, required this.codec, this.hops = 3}) {
    radio.state.addListener(_sync);
    _sync();
    _sub = radio.frames.listen(_onFrame);
  }

  final RadioLink radio;
  final EventCodec codec;

  /// How many radios a packet may hop through.
  final int hops;

  final _status = ValueNotifier(const LinkStatus(kind: LinkKind.lora, up: false));
  final _received = StreamController<Envelope>.broadcast();
  final _assembler = MeshPacketAssembler();
  late final StreamSubscription<Uint8List> _sub;

  /// What may travel over LoRa (also used by the demo's simulated radio).
  static bool carries(Envelope e) => e.priority != SendPriority.low && !e.needsEndToEnd;

  @override
  LinkKind get kind => LinkKind.lora;

  @override
  ValueListenable<LinkStatus> get status => _status;

  @override
  Stream<Envelope> get received => _received.stream;

  @override
  bool accepts(Envelope envelope) => carries(envelope) && codec.canEncode(envelope);

  void _sync() {
    final s = radio.state.value;
    _status.value = LinkStatus(
      kind: LinkKind.lora,
      up: s.available && s.connected,
      peers: s.peers,
      available: s.available,
    );
  }

  @override
  Future<void> start() => radio.start();

  @override
  Future<TransportAck> send(List<Envelope> batch) async {
    for (final e in batch) {
      final event = await codec.encode(e);
      final frames = MeshPacketCodec.split(
        event,
        maxFrameBytes: radio.maxFrameBytes,
        priority: e.kind == EnvelopeKind.sos
            ? WirePriority.critical
            : switch (e.priority) {
                SendPriority.urgent => WirePriority.high,
                SendPriority.normal => WirePriority.normal,
                SendPriority.low => WirePriority.low,
              },
        hops: hops,
      );
      for (final frame in frames) {
        try {
          await radio.send(frame);
        } on Object catch (err) {
          throw LinkDropped('$err');
        }
      }
    }
    return TransportAck.all(batch);
  }

  Future<void> _onFrame(Uint8List frame) async {
    final event = _assembler.add(frame);
    if (event == null || !await event.verify()) return;
    final envelope = EventCodec.decode(event);
    if (envelope != null && !_received.isClosed) _received.add(envelope);
  }

  @override
  void dispose() {
    radio.state.removeListener(_sync);
    _sub.cancel();
    _received.close();
    _status.dispose();
    radio.dispose();
  }
}
