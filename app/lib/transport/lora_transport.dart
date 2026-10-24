// LoraTransport: bridge to a Meshtastic radio over BLE (and serial/USB on
// Android/desktop) for the long-range, low-bandwidth mesh (spec §6.3).
//
// NEEDS REAL HARDWARE. This class talks to a physical Meshtastic radio (Heltec
// V3, LilyGO T-Beam, RAK4631, ...) running Meshtastic firmware. It cannot be
// exercised in CI or on web: there is no radio. The pure-Dart compaction,
// fragmentation, reassembly, and event-id dedupe all live in `lora_codec.dart`
// and ARE unit-tested there; this file is the thin radio adapter around them.
//
// Deployment notes (expanded in docs/NODE_SETUP.md / docs/HOW_IT_WORKS.md):
//   * Hardware: an ESP32/nRF52 LoRa board flashed with Meshtastic. Set the
//     correct region/frequency for your country (US915, EU868, ...) — using
//     the wrong band is illegal and will not interoperate.
//   * Channel key: all radios on a channel share a PSK; keep it off git and
//     distribute it out-of-band. The app's end-to-end signing is independent of
//     and layered above the Meshtastic channel crypto.
//   * Topology: a phone with no internet reaches a node with internet by
//     hopping over the mesh — the phone's LoraTransport sends compact signed
//     events to a nearby node running the Go LoRa gateway, which verifies and
//     stores them and rebroadcasts new SOS/alerts back out.
//
// This file deliberately uses no Meshtastic plugin import yet: the concrete
// radio binding (BLE via flutter_blue_plus, or serial) is wired at integration
// time on a real device. Keeping it decoupled means the web build never pulls
// in a native-only radio dependency, and the Transport abstraction stays clean.

import 'dart:async';
import 'dart:typed_data';

import '../gen/resilience/v1/event.pb.dart';
import 'lora_codec.dart';
import 'transport.dart';

/// Abstracts the physical Meshtastic link so the transport logic is testable
/// without a radio. A real implementation wraps flutter_blue_plus (BLE) or a
/// serial port; the in-memory fake used in tests just loops frames back.
abstract class MeshtasticLink {
  /// Sends one LoRa-sized frame (<= [LoraCodec.maxFragmentBytes]) to the mesh.
  Future<void> sendFrame(Uint8List frame);

  /// Frames heard on the mesh (including rebroadcasts).
  Stream<Uint8List> get frames;

  /// Whether the radio link is currently up.
  bool get isUp;

  Future<void> close();
}

/// A [Transport] that carries only compact signed events over a Meshtastic
/// mesh. Large or media-bearing events are refused by [LoraCodec].
///
/// There is a single logical "peer": the mesh itself. [connect] returns a
/// [LoraSession] that fragments outgoing [SignedEvent]s and reassembles
/// incoming ones, deduping by event id.
class LoraTransport extends Transport {
  LoraTransport({required MeshtasticLink link, this.name = 'lora-meshtastic'})
      : _link = link;

  final MeshtasticLink _link;

  @override
  final String name;

  int _msgIdCounter = 0;
  bool _started = false;

  @override
  TransportKind get kind => TransportKind.meshtastic;

  @override
  Future<void> start() async {
    _started = true;
  }

  @override
  Future<void> stop() async {
    _started = false;
    await _link.close();
  }

  @override
  Stream<DiscoveredPeer> discoverPeers() async* {
    if (_link.isUp) {
      yield const DiscoveredPeer(
        id: 'mesh',
        displayName: 'LoRa mesh',
        via: TransportKind.meshtastic,
      );
    }
  }

  @override
  Future<PeerSession> connect(DiscoveredPeer peer) async {
    if (!_started) throw StateError('Transport not started');
    return LoraSession(link: _link, nextMsgId: _nextMsgId);
  }

  int _nextMsgId() {
    _msgIdCounter = (_msgIdCounter + 1) & 0xffff;
    return _msgIdCounter;
  }
}

/// A [PeerSession] over the LoRa mesh.
///
/// Outgoing: the raw bytes handed to [send] are treated as a serialized
/// [SignedEvent]; if the event kind is LoRa-eligible and fits the budget it is
/// fragmented and each fragment is pushed to the radio. Ineligible / oversized
/// events are dropped (never sent) — honest behaviour, not a silent truncation.
///
/// Incoming: fragments are reassembled; each completed payload is surfaced on
/// [incoming] exactly once (deduped by content), to be verified by the caller's
/// EventStore before storing.
class LoraSession extends PeerSession {
  LoraSession({required MeshtasticLink link, required int Function() nextMsgId})
      : _link = link,
        _nextMsgId = nextMsgId {
    _sub = _link.frames.listen(_onFrame);
  }

  final MeshtasticLink _link;
  final int Function() _nextMsgId;
  final LoraReassembler _reassembler = LoraReassembler();
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _sub;
  bool _open = true;

  @override
  String get peerId => 'mesh';

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  bool get isOpen => _open && _link.isUp;

  @override
  Future<void> send(Uint8List frame) async {
    if (!_open) throw StateError('Session is closed');
    SignedEvent event;
    try {
      event = SignedEvent.fromBuffer(frame);
    } catch (_) {
      // Not a SignedEvent — the LoRa path only carries signed events.
      return;
    }
    if (!LoraCodec.isLoraEligible(event.header.type)) return;
    List<Uint8List> fragments;
    try {
      fragments = LoraCodec.fragmentEvent(event, msgId: _nextMsgId());
    } on LoraTooLargeException {
      return; // Too big for LoRa; refuse rather than corrupt.
    } on LoraIneligibleException {
      return;
    }
    for (final f in fragments) {
      await _link.sendFrame(f);
    }
  }

  void _onFrame(Uint8List frame) {
    final payload = _reassembler.addFragment(frame);
    if (payload != null && !_incoming.isClosed) {
      _incoming.add(payload);
    }
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    _open = false;
    await _sub?.cancel();
    if (!_incoming.isClosed) await _incoming.close();
  }
}
