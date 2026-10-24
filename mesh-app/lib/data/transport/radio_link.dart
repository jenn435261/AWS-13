import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What a native radio link reports.
class RadioLinkState {
  const RadioLinkState({
    this.available = false,
    this.connected = false,
    this.peers = 0,
    this.label = '',
  });

  /// The phone has the hardware, the permission and the native code.
  final bool available;

  /// Ready to send: a LoRa radio paired, or at least one phone in range.
  final bool connected;

  /// Phones in range (nearby links) or radios heard (LoRa).
  final int peers;

  /// The paired radio's name, e.g. "Meshtastic 3f2a".
  final String label;
}

/// A byte pipe the native side provides: a LoRa radio running Meshtastic,
/// or Bluetooth / Wi-Fi to phones nearby. The Dart side decides what the
/// bytes are (signed `resilience.v1` events); the native side only moves
/// them. Pigeon-style: one host API per link, described in
/// docs/app-backend-contract.md.
abstract class RadioLink {
  ValueListenable<RadioLinkState> get state;

  /// The largest frame [send] takes.
  int get maxFrameBytes;

  /// Starts the native side (asks for Bluetooth or nearby-devices
  /// permission there, if needed).
  Future<void> start();

  /// Sends one frame. Completes when the far end confirms it (Meshtastic
  /// want_ack, or the nearby phone's reply); throws when the link is gone.
  Future<void> send(Uint8List frame);

  /// Frames from the far end.
  Stream<Uint8List> get frames;

  void dispose();
}

/// [RadioLink] over a platform channel. Until the Android and iOS code
/// exists, [start] finds no plugin and the link reports itself
/// unavailable, so the app carries on with its other routes.
///
/// Channel contract (the native side implements):
///  * method `start` -> `{available: bool, connected: bool, peers: int, label: String}`
///  * method `send` with `{frame: Uint8List}` -> completes on the far
///    end's ack, or fails with a `PlatformException`
///  * event channel `<name>/events`: maps with `state` (same shape as
///    `start`) or `frame` (Uint8List)
class PlatformRadioLink implements RadioLink {
  PlatformRadioLink(String name, {required this.maxFrameBytes})
      : _methods = MethodChannel(name),
        _events = EventChannel('$name/events');

  /// A Meshtastic radio over Bluetooth (Android or iOS).
  factory PlatformRadioLink.lora() =>
      PlatformRadioLink('org.resilience.mesh/lora', maxFrameBytes: 233);

  /// Nearby phones over Bluetooth (Android Nearby Connections, iOS
  /// Multipeer Connectivity).
  factory PlatformRadioLink.bluetooth() =>
      PlatformRadioLink('org.resilience.mesh/nearby/bluetooth', maxFrameBytes: 32 * 1024);

  /// Nearby phones over Wi-Fi (Wi-Fi Direct / Aware, Multipeer).
  factory PlatformRadioLink.wifi() =>
      PlatformRadioLink('org.resilience.mesh/nearby/wifi', maxFrameBytes: 512 * 1024);

  final MethodChannel _methods;
  final EventChannel _events;

  @override
  final int maxFrameBytes;

  final _state = ValueNotifier(const RadioLinkState());
  final _frames = StreamController<Uint8List>.broadcast();
  StreamSubscription<Object?>? _sub;

  @override
  ValueListenable<RadioLinkState> get state => _state;

  @override
  Stream<Uint8List> get frames => _frames.stream;

  static RadioLinkState _readState(Object? raw) {
    final m = raw is Map ? raw : const {};
    return RadioLinkState(
      available: m['available'] == true,
      connected: m['connected'] == true,
      peers: (m['peers'] as num?)?.toInt() ?? 0,
      label: m['label'] as String? ?? '',
    );
  }

  @override
  Future<void> start() async {
    try {
      _state.value = _readState(await _methods.invokeMethod<Object?>('start'));
      _sub ??= _events.receiveBroadcastStream().listen((event) {
        if (event is! Map) return;
        if (event['state'] != null) _state.value = _readState(event['state']);
        final frame = event['frame'];
        if (frame is Uint8List) _frames.add(frame);
      }, onError: (Object _) {});
    } on MissingPluginException {
      _state.value = const RadioLinkState();
    } on PlatformException {
      _state.value = const RadioLinkState();
    }
  }

  @override
  Future<void> send(Uint8List frame) async {
    if (frame.length > maxFrameBytes) throw ArgumentError('frame too large');
    await _methods.invokeMethod<void>('send', {'frame': frame});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _frames.close();
    _state.dispose();
  }
}

/// Plays a native radio link for tests and previews.
class SimulatedRadioLink implements RadioLink {
  SimulatedRadioLink({
    this.maxFrameBytes = 233,
    bool connected = true,
    int peers = 1,
    this.latency = Duration.zero,
  }) : _state = ValueNotifier(RadioLinkState(
          available: true,
          connected: connected,
          peers: peers,
          label: 'Simulated',
        ));

  @override
  final int maxFrameBytes;
  final Duration latency;
  final ValueNotifier<RadioLinkState> _state;
  final _frames = StreamController<Uint8List>.broadcast();

  /// Every frame sent, in order.
  final sent = <Uint8List>[];

  /// Fails the send after this many more frames, as if the radio left.
  int? failAfter;

  @override
  ValueListenable<RadioLinkState> get state => _state;

  @override
  Stream<Uint8List> get frames => _frames.stream;

  void setConnected(bool connected, {int? peers}) => _state.value = RadioLinkState(
        available: true,
        connected: connected,
        peers: peers ?? _state.value.peers,
        label: _state.value.label,
      );

  /// Plays the far end sending [frame].
  void receive(Uint8List frame) => _frames.add(frame);

  @override
  Future<void> start() async {}

  @override
  Future<void> send(Uint8List frame) async {
    if (frame.length > maxFrameBytes) throw ArgumentError('frame too large');
    await Future<void>.delayed(latency);
    if (!_state.value.connected) throw const RadioGone();
    if (failAfter != null) {
      if (failAfter == 0) {
        failAfter = null;
        setConnected(false);
        throw const RadioGone();
      }
      failAfter = failAfter! - 1;
    }
    sent.add(frame);
  }

  @override
  void dispose() {
    _frames.close();
    _state.dispose();
  }
}

/// The simulated radio went away mid-send.
class RadioGone implements Exception {
  const RadioGone();
}
