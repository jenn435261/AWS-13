import 'dart:typed_data';

/// MTU-aware chunking for the BLE GATT transport (spec §6.2).
///
/// A BLE characteristic write carries at most `MTU - 3` payload bytes (the ATT
/// header is 3 bytes), and typical negotiated MTUs range from 23 (the default,
/// giving a 20-byte payload) up to 185-512 on modern phones. The sync engine,
/// however, hands us whole length-prefixed `SyncFrame`s that are usually larger
/// than one BLE packet. [BleChunker] fragments an outgoing frame into
/// MTU-sized packets and [BleReassembler] rebuilds the frame on the far side.
///
/// Unlike the LoRa path, BLE GATT writes are reliable and ordered (a notify/
/// write-with-response channel), so chunking here is plain sequential
/// fragmentation — no fountain code, no CRC per packet (the link layer already
/// guarantees integrity). The only job is to respect the MTU and recover frame
/// boundaries.
///
/// Packet layout (big-endian):
/// ```
/// flags    (1 byte)  bit0 = last packet of this frame
/// frameId  (2 bytes) groups packets belonging to the same logical frame
/// seq      (2 bytes) 0-based sequence within the frame
/// body     (rest)    frame slice, <= mtuPayload - headerLen
/// ```
///
/// The [frameId] lets the reassembler keep several in-flight frames apart when
/// a transport interleaves packets from back-to-back [chunk] calls (the sync
/// engine sends Hello, then Have, ... as separate frames).
class BleChunker {
  /// Per-packet header length.
  static const int headerLen = 5;

  /// Flag bit marking the final packet of a frame.
  static const int flagLast = 0x01;

  BleChunker._();

  /// Splits [frame] into packets each no larger than [mtuPayload] bytes
  /// (the usable payload per BLE write, i.e. negotiated MTU minus the 3-byte
  /// ATT header). [frameId] groups the packets of one logical frame so a
  /// reassembler can separate interleaved frames. Throws [ArgumentError] if
  /// [mtuPayload] leaves no room for a body.
  static List<Uint8List> chunk(Uint8List frame, int mtuPayload,
      {int frameId = 0}) {
    if (mtuPayload <= headerLen) {
      throw ArgumentError.value(
          mtuPayload, 'mtuPayload', 'must exceed the $headerLen-byte header');
    }
    final bodyMax = mtuPayload - headerLen;
    final packets = <Uint8List>[];
    final fid = frameId & 0xffff;
    if (frame.isEmpty) {
      // A zero-length frame is still one (empty, last) packet.
      final p = Uint8List(headerLen)
        ..[0] = flagLast
        ..[1] = (fid >> 8) & 0xff
        ..[2] = fid & 0xff;
      return <Uint8List>[p];
    }
    int seq = 0;
    for (int off = 0; off < frame.length; off += bodyMax) {
      final end = (off + bodyMax <= frame.length) ? off + bodyMax : frame.length;
      final isLast = end >= frame.length;
      final bodyLen = end - off;
      final p = Uint8List(headerLen + bodyLen);
      p[0] = isLast ? flagLast : 0x00;
      p[1] = (fid >> 8) & 0xff;
      p[2] = fid & 0xff;
      p[3] = (seq >> 8) & 0xff;
      p[4] = seq & 0xff;
      p.setRange(headerLen, headerLen + bodyLen, frame, off);
      packets.add(p);
      seq++;
    }
    return packets;
  }
}

/// Reassembles a single frame from sequential BLE packets.
///
/// The transport feeds every received packet via [addPacket]; it returns the
/// completed frame bytes when the packet with [BleChunker.flagLast] set arrives
/// and all preceding sequence numbers have been seen, otherwise null. Packets
/// are expected in order on a reliable GATT channel, but out-of-order or
/// duplicate packets are tolerated (indexed by sequence).
class BleReassembler {
  final Map<int, _FrameParts> _frames = <int, _FrameParts>{};

  /// Feeds one raw packet. Returns the complete frame when this packet finishes
  /// it, else null. Malformed packets (too short) are ignored. Packets from
  /// several interleaved frames are kept apart by their frame id.
  Uint8List? addPacket(Uint8List packet) {
    if (packet.length < BleChunker.headerLen) return null;
    final flags = packet[0];
    final frameId = (packet[1] << 8) | packet[2];
    final seq = (packet[3] << 8) | packet[4];
    final body = Uint8List.sublistView(packet, BleChunker.headerLen);

    final parts = _frames.putIfAbsent(frameId, () => _FrameParts());
    parts.parts[seq] = Uint8List.fromList(body);
    if ((flags & BleChunker.flagLast) != 0) {
      parts.lastSeq = seq;
    }
    if (parts.lastSeq == null) return null;
    for (int i = 0; i <= parts.lastSeq!; i++) {
      if (!parts.parts.containsKey(i)) return null;
    }
    final builder = BytesBuilder();
    for (int i = 0; i <= parts.lastSeq!; i++) {
      builder.add(parts.parts[i]!);
    }
    _frames.remove(frameId);
    return builder.toBytes();
  }
}

class _FrameParts {
  final Map<int, Uint8List> parts = <int, Uint8List>{};
  int? lastSeq;
}
