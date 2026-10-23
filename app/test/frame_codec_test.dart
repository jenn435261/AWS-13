import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/gen/resilience/v1/sync.pb.dart';
import 'package:resilience/sync/frame_codec.dart';

SyncFrame _helloFrame(String version, int hw) => SyncFrame(
      hello: Hello(
        softwareVersion: version,
        lamportHighWater: Int64(hw),
      ),
    );

SyncFrame _ackFrame(List<List<int>> applied) =>
    SyncFrame(ack: Ack(applied: applied));

void main() {
  test('round-trips a single SyncFrame', () {
    final frame = _helloFrame('v1.2.3', 42);
    final encoded = FrameCodec.encodeFrame(frame);

    final decoder = FrameDecoder();
    final frames = decoder.addChunk(encoded);

    expect(frames, hasLength(1));
    expect(frames.first.whichFrame(), SyncFrame_Frame.hello);
    expect(frames.first.hello.softwareVersion, 'v1.2.3');
    expect(frames.first.hello.lamportHighWater.toInt(), 42);
    expect(decoder.hasPartial, isFalse);
  });

  test('reassembles a frame split across arbitrary chunk boundaries', () {
    final frame = _helloFrame('split-test', 7);
    final encoded = FrameCodec.encodeFrame(frame);

    // Feed one byte at a time; a complete frame should only emerge on the last.
    final decoder = FrameDecoder();
    final collected = <SyncFrame>[];
    for (int i = 0; i < encoded.length; i++) {
      final out = decoder.addChunk(Uint8List.fromList([encoded[i]]));
      collected.addAll(out);
      if (i < encoded.length - 1) {
        expect(out, isEmpty, reason: 'no full frame until the last byte');
      }
    }

    expect(collected, hasLength(1));
    expect(collected.first.hello.softwareVersion, 'split-test');
  });

  test('decodes multiple frames in one buffer, in order', () {
    final f1 = _helloFrame('first', 1);
    final f2 = _ackFrame([
      [1, 2, 3],
      [4, 5, 6],
    ]);
    final f3 = _helloFrame('third', 3);

    final buffer = BytesBuilder();
    buffer.add(FrameCodec.encodeFrame(f1));
    buffer.add(FrameCodec.encodeFrame(f2));
    buffer.add(FrameCodec.encodeFrame(f3));

    final decoder = FrameDecoder();
    final frames = decoder.addChunk(buffer.toBytes());

    expect(frames, hasLength(3));
    expect(frames[0].hello.softwareVersion, 'first');
    expect(frames[1].whichFrame(), SyncFrame_Frame.ack);
    expect(frames[1].ack.applied, hasLength(2));
    expect(frames[2].hello.softwareVersion, 'third');
    expect(decoder.hasPartial, isFalse);
  });

  test('handles a buffer containing complete frames plus a partial tail', () {
    final f1 = _helloFrame('complete', 9);
    final f2 = _helloFrame('partial-tail', 10);

    final e1 = FrameCodec.encodeFrame(f1);
    final e2 = FrameCodec.encodeFrame(f2);

    // First chunk: all of f1 plus half of f2.
    final cut = e2.length ~/ 2;
    final decoder = FrameDecoder();

    final part1 = Uint8List(e1.length + cut)
      ..setRange(0, e1.length, e1)
      ..setRange(e1.length, e1.length + cut, e2.sublist(0, cut));

    final firstOut = decoder.addChunk(part1);
    expect(firstOut, hasLength(1));
    expect(firstOut.first.hello.softwareVersion, 'complete');
    expect(decoder.hasPartial, isTrue);

    // Second chunk: the rest of f2.
    final secondOut = decoder.addChunk(e2.sublist(cut));
    expect(secondOut, hasLength(1));
    expect(secondOut.first.hello.softwareVersion, 'partial-tail');
    expect(decoder.hasPartial, isFalse);
  });
}
