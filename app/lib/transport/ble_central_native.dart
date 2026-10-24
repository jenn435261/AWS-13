// Native BLE central adapter wiring the platform-agnostic [BleLink]/
// [BleRawChannel] seam in `ble_transport.dart` to `flutter_blue_plus`.
//
// NEEDS REAL DEVICES. This file imports a native-only plugin and therefore must
// NEVER be imported by web-reachable code — the web build would break. It is
// imported only from native entry points (e.g. a platform-gated provider that
// is `kIsWeb`-guarded). The transport LOGIC (chunking, encryption, pairing,
// sync wiring) lives in web-safe files and is unit-tested without a radio; this
// adapter is the thin, device-only binding.
//
// Role split (spec §6.2):
//   * This adapter is the CENTRAL: it scans for peripherals advertising
//     [BleTransport.serviceUuid], connects, negotiates the MTU, discovers the
//     sync characteristic, subscribes to notifications, and writes packets.
//   * The PERIPHERAL side (advertising the service, exposing the writable/
//     notifiable characteristic) is provided by a peripheral plugin
//     (`flutter_ble_peripheral` or `bluetooth_low_energy`) on the other phone.
//     Android<->iOS works because both expose the same custom GATT service.
//
// The 6-digit pairing / identity-QR step (see `ble_pairing.dart`) runs BEFORE
// a session is trusted, and the per-session key derived there encrypts every
// frame carried over this adapter.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_chunker.dart';
import 'ble_transport.dart';
import 'transport.dart';

/// A [BleLink] over flutter_blue_plus (central role).
class FlutterBluePlusLink extends BleLink {
  FlutterBluePlusLink();

  final Guid _service = Guid(BleTransport.serviceUuid);
  final Guid _characteristic = Guid(BleTransport.characteristicUuid);

  StreamSubscription<List<ScanResult>>? _scanSub;
  final StreamController<DiscoveredPeer> _peers =
      StreamController<DiscoveredPeer>.broadcast();

  @override
  Future<void> start() async {
    // The caller is responsible for runtime permission prompts. We begin a
    // filtered scan for peripherals advertising our custom service.
    await FlutterBluePlus.startScan(withServices: <Guid>[_service]);
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        _peers.add(DiscoveredPeer(
          id: r.device.remoteId.str,
          displayName: r.device.platformName.isEmpty
              ? r.device.remoteId.str
              : r.device.platformName,
          via: TransportKind.bluetooth,
        ));
      }
    });
  }

  @override
  Future<void> stop() async {
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    if (!_peers.isClosed) await _peers.close();
  }

  @override
  Stream<DiscoveredPeer> discover() => _peers.stream;

  @override
  Future<BleRawChannel> connect(String peerId) async {
    final device = BluetoothDevice.fromId(peerId);
    await device.connect(timeout: const Duration(seconds: 15));
    // Request a large MTU; the OS clamps to what it supports.
    int mtu = 23;
    try {
      mtu = await device.requestMtu(512);
    } catch (_) {
      mtu = device.mtuNow;
    }
    final services = await device.discoverServices();
    BluetoothCharacteristic? sync;
    for (final s in services) {
      if (s.uuid == _service) {
        for (final c in s.characteristics) {
          if (c.uuid == _characteristic) {
            sync = c;
            break;
          }
        }
      }
    }
    if (sync == null) {
      await device.disconnect();
      throw StateError('Resilience sync characteristic not found on $peerId');
    }
    await sync.setNotifyValue(true);
    return _FbpChannel(device: device, characteristic: sync, mtu: mtu);
  }
}

class _FbpChannel extends BleRawChannel {
  _FbpChannel({
    required BluetoothDevice device,
    required BluetoothCharacteristic characteristic,
    required int mtu,
  })  : _device = device,
        _char = characteristic,
        // mtuPayload is the negotiated MTU minus the 3-byte ATT header; we also
        // reserve the BLE chunk header inside the payload budget.
        mtuPayload = (mtu - 3) < BleChunker.headerLen + 1
            ? BleChunker.headerLen + 1
            : (mtu - 3) {
    _sub = _char.onValueReceived.listen((v) {
      if (!_incoming.isClosed) _incoming.add(Uint8List.fromList(v));
    });
  }

  final BluetoothDevice _device;
  final BluetoothCharacteristic _char;
  @override
  final int mtuPayload;

  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  StreamSubscription<List<int>>? _sub;
  bool _open = true;

  @override
  Stream<Uint8List> get packets => _incoming.stream;

  @override
  bool get isOpen => _open;

  @override
  Future<void> sendPacket(Uint8List packet) async {
    // Write-without-response keeps throughput up; the GATT link is reliable.
    await _char.write(packet, withoutResponse: true);
  }

  @override
  Future<void> close() async {
    _open = false;
    await _sub?.cancel();
    if (!_incoming.isClosed) await _incoming.close();
    try {
      await _device.disconnect();
    } catch (_) {}
  }
}
