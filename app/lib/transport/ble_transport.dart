import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'ble_chunker.dart';
import 'transport.dart';

/// BLE GATT [Transport] (spec §6.2): carries the existing signed-event sync
/// (have/push/pull frames) between an Android and an iOS phone over a custom
/// GATT service, with MTU-aware chunking, a short pairing step, and per-session
/// encryption keyed from the contacts' identity keys.
///
/// NEEDS REAL DEVICES. The radio itself — scanning, GATT connect, MTU
/// negotiation, characteristic notify/write — is native-only and lives behind
/// the [BleLink] abstraction. A real implementation wraps `flutter_blue_plus`
/// (central role) and a peripheral plugin (`flutter_ble_peripheral` /
/// `bluetooth_low_energy`) advertising [serviceUuid]. This file contains only
/// platform-agnostic logic (chunk/reassemble, encrypt/decrypt, frame wiring)
/// so it compiles and is unit-testable with no Bluetooth present; the web build
/// never imports a native-only BLE plugin.
///
/// The sync engine is unchanged: it still talks to a [PeerSession] and neither
/// knows nor cares that the bytes crossed a BLE GATT link.
class BleTransport extends Transport {
  BleTransport({
    required BleLink link,
    required Uint8List sessionKey,
    int mtuPayload = 180,
    this.name = 'ble-gatt',
  })  : _link = link,
        _sessionKey = sessionKey,
        _mtuPayload = mtuPayload;

  /// Custom 128-bit GATT service UUID for the Resilience sync characteristic.
  /// Advertised by the peripheral; scanned for by the central.
  static const String serviceUuid = '7265736c-0001-4000-8000-72657369696e';

  /// Custom characteristic UUID carrying chunked, encrypted sync frames.
  static const String characteristicUuid =
      '7265736c-0002-4000-8000-72657369696e';

  final BleLink _link;
  final Uint8List _sessionKey;
  final int _mtuPayload;

  @override
  final String name;

  bool _started = false;

  @override
  TransportKind get kind => TransportKind.bluetooth;

  @override
  Future<void> start() async {
    _started = true;
    await _link.start();
  }

  @override
  Future<void> stop() async {
    _started = false;
    await _link.stop();
  }

  @override
  Stream<DiscoveredPeer> discoverPeers() => _link.discover();

  @override
  Future<PeerSession> connect(DiscoveredPeer peer) async {
    if (!_started) throw StateError('Transport not started');
    final raw = await _link.connect(peer.id);
    return BleSession(
      peerId: peer.id,
      raw: raw,
      sessionKey: _sessionKey,
      mtuPayload: raw.mtuPayload > 0 ? raw.mtuPayload : _mtuPayload,
    );
  }
}

/// The platform-agnostic BLE link seam. A real implementation wraps
/// flutter_blue_plus + a peripheral plugin; tests use an in-memory fake.
abstract class BleLink {
  Future<void> start();
  Future<void> stop();
  Stream<DiscoveredPeer> discover();

  /// Opens a raw packet channel to the peer with the negotiated MTU.
  Future<BleRawChannel> connect(String peerId);
}

/// A raw BLE packet channel: send/receive MTU-sized packets (post-ATT-header).
abstract class BleRawChannel {
  /// Usable payload bytes per packet (negotiated MTU minus the 3-byte header).
  int get mtuPayload;

  Stream<Uint8List> get packets;
  Future<void> sendPacket(Uint8List packet);
  Future<void> close();
  bool get isOpen;
}

/// A [PeerSession] over a BLE GATT raw channel.
///
/// Outgoing frames are AES-GCM encrypted with the per-session key, then chunked
/// to the MTU. Incoming packets are reassembled then decrypted. Decryption
/// failures (tampered/foreign packets) are dropped silently; the sync engine
/// only ever sees authentic frame bytes.
class BleSession extends PeerSession {
  BleSession({
    required this.peerId,
    required BleRawChannel raw,
    required Uint8List sessionKey,
    required int mtuPayload,
  })  : _raw = raw,
        _key = SecretKey(sessionKey),
        _mtuPayload = mtuPayload {
    _sub = _raw.packets.listen(_onPacket);
  }

  @override
  final String peerId;

  final BleRawChannel _raw;
  final SecretKey _key;
  final int _mtuPayload;

  static final AesGcm _aead = AesGcm.with256bits();

  final BleReassembler _reassembler = BleReassembler();
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _sub;
  bool _open = true;
  int _frameId = 0;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  bool get isOpen => _open && _raw.isOpen;

  @override
  Future<void> send(Uint8List frame) async {
    if (!_open) throw StateError('Session is closed');
    final sealed = await _encrypt(frame);
    final fid = _frameId;
    _frameId = (_frameId + 1) & 0xffff;
    final packets = BleChunker.chunk(sealed, _mtuPayload, frameId: fid);
    for (final p in packets) {
      await _raw.sendPacket(p);
    }
  }

  Future<void> _onPacket(Uint8List packet) async {
    final sealed = _reassembler.addPacket(packet);
    if (sealed == null) return;
    final plain = await _decrypt(sealed);
    if (plain != null && !_incoming.isClosed) {
      _incoming.add(plain);
    }
  }

  Future<Uint8List> _encrypt(Uint8List plain) async {
    final box = await _aead.encrypt(plain, secretKey: _key);
    // Wire: [nonce(12)][ciphertext...][mac(16)].
    final out = BytesBuilder()
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return out.toBytes();
  }

  Future<Uint8List?> _decrypt(Uint8List sealed) async {
    const nonceLen = 12;
    const macLen = 16;
    if (sealed.length < nonceLen + macLen) return null;
    try {
      final nonce = sealed.sublist(0, nonceLen);
      final cipher = sealed.sublist(nonceLen, sealed.length - macLen);
      final mac = Mac(sealed.sublist(sealed.length - macLen));
      final box = SecretBox(cipher, nonce: nonce, mac: mac);
      final clear = await _aead.decrypt(box, secretKey: _key);
      return Uint8List.fromList(clear);
    } catch (_) {
      // Tampered or foreign packet: drop. Never surface forged bytes.
      return null;
    }
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    _open = false;
    await _sub?.cancel();
    await _raw.close();
    if (!_incoming.isClosed) await _incoming.close();
  }
}
