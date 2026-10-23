import 'dart:typed_data';

/// The physical/logical medium a [Transport] moves bytes over.
///
/// The sync engine is deliberately agnostic to this — see the module doc below.
enum TransportKind {
  /// TCP/WebSocket to a reachable node over the public internet.
  internet,

  /// Local Wi-Fi: Wi-Fi Direct on Android, Multipeer (local Wi-Fi/AWDL) on
  /// Apple platforms.
  localWifi,

  /// Classic/BLE Bluetooth.
  bluetooth,

  /// LoRa / Meshtastic long-range low-bandwidth mesh.
  meshtastic,

  /// A relay/cloud node acting as a store-and-forward hop.
  node,
}

/// A peer that a [Transport] has discovered and can be connected to.
///
/// [id] is transport-specific (MAC address, MCPeerID, node url, …) and only
/// has to be meaningful to the transport that produced it. [displayName] is a
/// human-friendly label; [via] records which medium found the peer.
class DiscoveredPeer {
  final String id;
  final String displayName;
  final TransportKind via;

  const DiscoveredPeer({
    required this.id,
    required this.displayName,
    required this.via,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredPeer &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          via == other.via;

  @override
  int get hashCode => Object.hash(id, displayName, via);

  @override
  String toString() =>
      'DiscoveredPeer(id: $id, displayName: $displayName, via: $via)';
}

/// A bidirectional, ordered, reliable byte-frame channel with one peer.
///
/// A session hands the sync engine *frames* (whole `Uint8List`s that the
/// transport guarantees to deliver intact and in order). The engine wraps
/// `SyncFrame` protobufs with a length prefix via `FrameDecoder`, but the
/// `PeerSession` contract itself is just "send bytes, receive bytes".
abstract class PeerSession {
  /// The id of the peer on the other end of this session.
  String get peerId;

  /// Frames received from the peer. Each event is one logical frame as handed
  /// to [send] on the other side (transports that only offer a raw byte stream
  /// should still emit whatever chunks arrive; the `FrameDecoder` reassembles).
  Stream<Uint8List> get incoming;

  /// Sends a single frame to the peer.
  Future<void> send(Uint8List frame);

  /// Closes the session and releases any underlying resources.
  Future<void> close();

  /// Whether the session is currently usable.
  bool get isOpen;
}

/// A transport-agnostic way to discover peers and open [PeerSession]s to them.
///
/// ## The sync engine neither knows nor cares which transport moved the bytes
/// (spec §39).
///
/// This is the single most important design property of the networking layer.
/// `SyncEngine` is constructed from an `EventStore` and a [PeerSession]; it
/// only ever calls [PeerSession.send] and listens to [PeerSession.incoming].
/// Whether those bytes travelled over the internet, Wi-Fi Direct, Bluetooth, a
/// LoRa mesh, or an in-memory pipe in a unit test is entirely invisible to the
/// reconciliation protocol. New transports can be added by implementing this
/// interface without touching a line of sync code, and the exact same
/// convergence guarantees hold regardless of medium. The in-memory transport
/// used in tests and the real `nearby_service` transport are interchangeable
/// from the engine's point of view.
abstract class Transport {
  /// A short, stable, human-readable name for this transport implementation.
  String get name;

  /// The medium this transport uses.
  TransportKind get kind;

  /// Starts the transport (acquire radios, open listeners, …).
  Future<void> start();

  /// Stops the transport and releases resources.
  Future<void> stop();

  /// A continuously-updated stream of peers this transport can see.
  Stream<DiscoveredPeer> discoverPeers();

  /// Opens a [PeerSession] to [peer]. Completes when the channel is ready to
  /// carry frames.
  Future<PeerSession> connect(DiscoveredPeer peer);
}
