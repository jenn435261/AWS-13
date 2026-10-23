import 'dart:async';
import 'dart:typed_data';

import 'transport.dart';

/// An entirely in-process [Transport]/[PeerSession] pair.
///
/// This exists so the sync engine can be exercised end-to-end — proving two
/// independent stores converge — without any radios, platform channels, or
/// hardware. Because `SyncEngine` only talks to the [PeerSession] abstraction,
/// swapping the real `nearby_service` transport for this in-memory one changes
/// nothing about the protocol: it is the clean seam that makes convergence unit
/// testable.
///
/// Create a linked pair with [InMemoryTransport.pair]; a frame sent on one
/// side's [PeerSession] arrives on the other side's [PeerSession.incoming].
class InMemoryTransport extends Transport {
  @override
  final String name;

  final String _selfId;
  final String _peerId;

  // Broadcast of peers this side can "discover".
  final StreamController<DiscoveredPeer> _discovery =
      StreamController<DiscoveredPeer>.broadcast();

  // The session for this side, wired to the partner at pair() time.
  late final InMemorySession _session;

  bool _started = false;

  InMemoryTransport._({
    required this.name,
    required String selfId,
    required String peerId,
  })  : _selfId = selfId,
        _peerId = peerId;

  @override
  TransportKind get kind => TransportKind.node;

  /// The id this transport presents as.
  String get selfId => _selfId;

  /// Creates two transports whose sessions are cross-wired: bytes written on
  /// [a]'s session are readable on [b]'s session and vice versa.
  static (InMemoryTransport, InMemoryTransport) pair({
    String aId = 'A',
    String bId = 'B',
  }) {
    final a = InMemoryTransport._(name: 'in-memory($aId)', selfId: aId, peerId: bId);
    final b = InMemoryTransport._(name: 'in-memory($bId)', selfId: bId, peerId: aId);

    // Two one-way byte pipes.
    final aToB = StreamController<Uint8List>.broadcast();
    final bToA = StreamController<Uint8List>.broadcast();

    // a.send -> aToB -> b.incoming ; b.send -> bToA -> a.incoming
    a._session = InMemorySession(
      peerId: bId,
      outbound: aToB,
      inbound: bToA.stream,
    );
    b._session = InMemorySession(
      peerId: aId,
      outbound: bToA,
      inbound: aToB.stream,
    );
    return (a, b);
  }

  @override
  Future<void> start() async {
    _started = true;
    // Advertise the single known partner as a discovered peer.
    _discovery.add(DiscoveredPeer(
      id: _peerId,
      displayName: _peerId,
      via: kind,
    ));
  }

  @override
  Future<void> stop() async {
    _started = false;
    await _session.close();
    await _discovery.close();
  }

  @override
  Stream<DiscoveredPeer> discoverPeers() => _discovery.stream;

  @override
  Future<PeerSession> connect(DiscoveredPeer peer) async {
    if (!_started) {
      throw StateError('Transport not started');
    }
    return _session;
  }

  /// Direct access to this side's session (handy in tests that skip discovery).
  InMemorySession get session => _session;
}

/// In-memory [PeerSession]: an outbound sink feeding the partner and an inbound
/// stream fed by the partner.
class InMemorySession extends PeerSession {
  @override
  final String peerId;

  final StreamController<Uint8List> _outbound;
  final Stream<Uint8List> _inbound;

  bool _open = true;

  InMemorySession({
    required this.peerId,
    required StreamController<Uint8List> outbound,
    required Stream<Uint8List> inbound,
  })  : _outbound = outbound,
        _inbound = inbound;

  @override
  Stream<Uint8List> get incoming => _inbound;

  @override
  bool get isOpen => _open;

  @override
  Future<void> send(Uint8List frame) async {
    if (!_open) {
      throw StateError('Session is closed');
    }
    if (!_outbound.isClosed) {
      // Defensive copy so a caller mutating the buffer cannot corrupt in-flight
      // frames (mirrors what a real transport's serialisation would do).
      _outbound.add(Uint8List.fromList(frame));
    }
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    _open = false;
    if (!_outbound.isClosed) {
      await _outbound.close();
    }
  }
}
