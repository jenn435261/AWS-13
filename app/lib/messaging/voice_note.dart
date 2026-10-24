import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

/// Hold-to-record voice notes for secure messaging (spec §6: Opus/AAC mono,
/// <=60s). Thin wrapper over the web-safe `record` (capture) and `audioplayers`
/// (playback) packages, with honest capability checks so the UI never crashes
/// when the mic is unavailable.
class VoiceRecorder {
  VoiceRecorder({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  DateTime? _startedAt;

  /// Max recording length (spec §6).
  static const Duration maxDuration = Duration(seconds: 60);

  /// Whether recording is permitted (mic permission granted + hardware
  /// present). Returns false instead of throwing when unavailable.
  Future<bool> isAvailable() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Begin recording to an AAC (mono) stream. Returns false if the mic is
  /// unavailable (caller shows an honest message).
  Future<bool> start() async {
    try {
      if (!await _recorder.hasPermission()) return false;
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          bitRate: 24000,
        ),
        path: _tempPath(),
      );
      _startedAt = DateTime.now();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Whether a recording is in progress.
  Future<bool> get isRecording async {
    try {
      return await _recorder.isRecording();
    } catch (_) {
      return false;
    }
  }

  /// Elapsed recording time (0 when not recording).
  Duration get elapsed =>
      _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);

  /// Stop recording and return the captured bytes plus duration, or null if
  /// nothing was captured. Clamped to [maxDuration].
  Future<VoiceClip?> stop() async {
    try {
      final path = await _recorder.stop();
      final duration = elapsed;
      _startedAt = null;
      if (path == null) return null;
      final bytes = await _readPath(path);
      if (bytes == null || bytes.isEmpty) return null;
      final clamped =
          duration > maxDuration ? maxDuration : duration;
      return VoiceClip(bytes: bytes, duration: clamped, mime: 'audio/aac');
    } catch (_) {
      _startedAt = null;
      return null;
    }
  }

  /// Cancel an in-progress recording, discarding any bytes.
  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } catch (_) {
      // ignore
    }
    _startedAt = null;
  }

  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (_) {}
  }

  String _tempPath() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    // On web the `record` plugin ignores the path and returns a blob URL; on
    // native this is a scratch file. Either way we read the bytes back.
    return 'voice_$ts.m4a';
  }

  Future<Uint8List?> _readPath(String path) async {
    // On web, `path` is a blob URL fetched by the player; on native it is a
    // file path. Reading bytes is delegated to the caller's platform-specific
    // reader via [bytesReader] so this class stays dart:io-free for web.
    final reader = bytesReader;
    if (reader == null) return null;
    return reader(path);
  }

  /// Platform byte reader injected by the UI layer (native uses dart:io; web
  /// fetches the blob URL). Left null keeps this class web-compilable.
  static Future<Uint8List?> Function(String path)? bytesReader;
}

/// A captured voice note.
class VoiceClip {
  VoiceClip({required this.bytes, required this.duration, required this.mime});
  final Uint8List bytes;
  final Duration duration;
  final String mime;
}

/// Plays back a received voice note from in-memory bytes.
class VoicePlayer {
  VoicePlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer();
  final AudioPlayer _player;

  Future<void> playBytes(Uint8List bytes, {String mime = 'audio/aac'}) async {
    await _player.play(BytesSource(bytes, mimeType: mime));
  }

  Future<void> stop() => _player.stop();

  Stream<Duration> get onPosition => _player.onPositionChanged;

  Future<void> dispose() => _player.dispose();
}
