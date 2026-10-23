import 'dart:typed_data';

import '../gen/resilience/v1/sync.pb.dart';

/// Length-prefixed framing of [SyncFrame] protobufs over a raw byte stream.
///
/// A transport may deliver bytes in arbitrary chunks: a single [SyncFrame] can
/// arrive split across several reads, and several frames can arrive coalesced
/// into one read. To recover message boundaries we prefix every encoded frame
/// with its length as a 4-byte big-endian unsigned integer:
///
/// ```
/// +----------------+-------------------------------+
/// | len (uint32 BE)| protobuf-encoded SyncFrame     |
/// +----------------+-------------------------------+
/// ```
///
/// [encodeFrame] produces that wire form; [FrameDecoder] accumulates incoming
/// chunks and yields complete [SyncFrame]s as soon as enough bytes are present,
/// correctly handling partial reads and multiple frames in a single buffer.
class FrameCodec {
  FrameCodec._();

  /// Number of bytes in the big-endian length prefix.
  static const int prefixLength = 4;

  /// Encodes [frame] as a length-prefixed byte buffer.
  static Uint8List encodeFrame(SyncFrame frame) {
    final Uint8List body = frame.writeToBuffer();
    final Uint8List out = Uint8List(prefixLength + body.length);
    final ByteData header = ByteData.view(out.buffer, 0, prefixLength);
    header.setUint32(0, body.length, Endian.big);
    out.setRange(prefixLength, out.length, body);
    return out;
  }
}

/// Convenience top-level mirror of [FrameCodec.encodeFrame].
Uint8List encodeFrame(SyncFrame frame) => FrameCodec.encodeFrame(frame);

/// Stateful decoder that reassembles [SyncFrame]s from a stream of byte chunks.
///
/// Feed it whatever bytes arrive from the transport via [addChunk]; it returns
/// every complete frame contained in the accumulated buffer so far (possibly
/// zero, possibly many). Any trailing partial frame is retained until the rest
/// of its bytes arrive in a later chunk.
class FrameDecoder {
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  /// Appends [chunk] to the internal buffer and returns any frames that are now
  /// fully available, in arrival order.
  List<SyncFrame> addChunk(List<int> chunk) {
    if (chunk.isNotEmpty) {
      _buffer.add(chunk);
    }
    return _drain();
  }

  List<SyncFrame> _drain() {
    final List<SyncFrame> frames = <SyncFrame>[];
    // Snapshot the buffer so we can inspect it, then rebuild with the leftover.
    Uint8List data = _buffer.toBytes();
    int offset = 0;

    while (true) {
      final int remaining = data.length - offset;
      if (remaining < FrameCodec.prefixLength) {
        break;
      }
      final ByteData view =
          ByteData.view(data.buffer, data.offsetInBytes + offset, FrameCodec.prefixLength);
      final int bodyLen = view.getUint32(0, Endian.big);
      final int frameEnd = offset + FrameCodec.prefixLength + bodyLen;
      if (data.length < frameEnd) {
        // Body not fully arrived yet.
        break;
      }
      final Uint8List body = Uint8List.sublistView(
        data,
        offset + FrameCodec.prefixLength,
        frameEnd,
      );
      frames.add(SyncFrame.fromBuffer(body));
      offset = frameEnd;
    }

    // Reset the buffer to whatever bytes remain unconsumed.
    _buffer.clear();
    if (offset < data.length) {
      _buffer.add(Uint8List.sublistView(data, offset));
    }
    return frames;
  }

  /// Whether unconsumed (partial-frame) bytes remain buffered.
  bool get hasPartial => _buffer.length > 0;

  /// Drops any buffered bytes.
  void reset() => _buffer.clear();
}
