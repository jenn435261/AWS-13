// Concrete [Transport] backed by the `nearby_service` plugin.
//
// Platform reality this wraps:
//   * Android uses **Wi-Fi Direct** (Wi-Fi P2P) for local peer connections.
//   * iOS / macOS use **Multipeer Connectivity** (local Wi-Fi / AWDL / BT).
//   * Android <-> iOS *direct* P2P is NOT possible: the two OS frameworks are
//     mutually incompatible at the radio/protocol layer. Cross-platform sync
//     therefore has to flow through a common hop — a relay Node (internet) or a
//     LoRa/Meshtastic mesh — rather than a direct nearby session. Keep that in
//     mind when reasoning about topology; this transport only ever links
//     same-family devices.
//
// This file performs platform-channel calls (device discovery, connection,
// communication channel, message send/receive) and so cannot run in a plain
// Dart/Flutter unit test. All of that lives behind the [Transport]/[PeerSession]
// abstraction; the sync engine is tested against the in-memory transport
// instead. Do NOT instantiate this class in a unit test.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nearby_service/nearby_service.dart';

import 'transport.dart';

/// A [Transport] over `nearby_service` (Wi-Fi Direct on Android, Multipeer on
/// Apple platforms).
///
/// Frames are arbitrary bytes but the plugin's reliable channel carries text
/// messages, so each frame is base64-encoded into a [NearbyMessageTextRequest]
/// on the way out and decoded back to bytes on the way in. The sync engine is
/// oblivious to this: it only ever sees the [PeerSession] byte contract.
class NearbyTransport extends Transport {
  final NearbyService _service;

  @override
  final String name;

  final StreamController<DiscoveredPeer> _peers =
      StreamController<DiscoveredPeer>.broadcast();
  StreamSubscription<List<NearbyDevice>>? _peersSub;

  NearbyTransport({NearbyService? service, this.name = 'nearby_service'})
      : _service = service ?? NearbyService.getInstance();

  @override
  TransportKind get kind => TransportKind.localWifi;

  @override
  Future<void> start() async {
    await _service.initialize();
    await _service.discover();
    _peersSub = _service.getPeersStream().listen((devices) {
      for (final NearbyDevice d in devices) {
        _peers.add(DiscoveredPeer(
          id: d.info.id,
          displayName: d.info.displayName,
          via: kind,
        ));
      }
    });
  }

  @override
  Future<void> stop() async {
    await _peersSub?.cancel();
    _peersSub = null;
    try {
      await _service.stopDiscovery();
    } catch (_) {
      // Best-effort; the platform may already be stopped.
    }
    if (!_peers.isClosed) {
      await _peers.close();
    }
  }

  @override
  Stream<DiscoveredPeer> discoverPeers() => _peers.stream;

  @override
  Future<PeerSession> connect(DiscoveredPeer peer) async {
    final bool connected = await _service.connectById(peer.id);
    if (!connected) {
      throw StateError('nearby_service failed to connect to ${peer.id}');
    }

    final session = NearbyPeerSession._(
      service: _service,
      peerId: peer.id,
    );

    // Resolve the receiver info (needed to address outgoing messages).
    NearbyDeviceInfo? receiver;
    final List<NearbyDevice> known = await _service.getPeers();
    for (final NearbyDevice d in known) {
      if (d.info.id == peer.id) {
        receiver = d.info;
        break;
      }
    }
    receiver ??= NearbyDeviceInfo(displayName: peer.displayName, id: peer.id);
    session._receiver = receiver;

    // Open the communication channel and route decoded bytes into the session.
    await _service.startCommunicationChannel(
      NearbyCommunicationChannelData(
        peer.id,
        messagesListener: NearbyServiceMessagesListener(
          onData: session._onMessage,
          onDone: session._onDone,
          onError: (Object e, [StackTrace? st]) => session._onError(e),
        ),
      ),
    );

    return session;
  }
}

/// [PeerSession] over a `nearby_service` communication channel.
class NearbyPeerSession extends PeerSession {
  final NearbyService _service;

  @override
  final String peerId;

  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();

  NearbyDeviceInfo? _receiver;
  bool _open = true;

  NearbyPeerSession._({
    required NearbyService service,
    required this.peerId,
  }) : _service = service;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  bool get isOpen => _open;

  @override
  Future<void> send(Uint8List frame) async {
    if (!_open) {
      throw StateError('Session is closed');
    }
    final NearbyDeviceInfo receiver =
        _receiver ?? NearbyDeviceInfo(displayName: peerId, id: peerId);
    final String encoded = base64Encode(frame);
    await _service.send(
      OutgoingNearbyMessage<NearbyMessageTextRequest>(
        content: NearbyMessageTextRequest.create(value: encoded),
        receiver: receiver,
      ),
    );
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    _open = false;
    try {
      await _service.endCommunicationChannel();
    } catch (_) {
      // Best-effort.
    }
    try {
      await _service.disconnectById(peerId);
    } catch (_) {
      // Best-effort.
    }
    if (!_incoming.isClosed) {
      await _incoming.close();
    }
  }

  void _onMessage(ReceivedNearbyMessage message) {
    message.content.byType(
      onTextRequest: (req) {
        try {
          _incoming.add(base64Decode(req.value));
        } catch (_) {
          // Ignore undecodable payloads; they are not our frames.
        }
        return null;
      },
    );
  }

  void _onDone() {
    if (!_incoming.isClosed) {
      _incoming.close();
    }
    _open = false;
  }

  void _onError(Object error) {
    if (!_incoming.isClosed) {
      _incoming.addError(error);
    }
  }
}
