import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/transport/transport.dart';
import 'package:resilience/transport/transport_status.dart';

void main() {
  group('radioTransportRows honesty', () {
    test('web: Nearby/BLE/LoRa are unavailable, QR is idle', () {
      final rows = radioTransportRows(isWeb: true);
      final byKind = {for (final r in rows) r.labelKey: r};
      expect(byKind['transport_nearby']!.state, TransportState.unavailableHere);
      expect(byKind['transport_ble']!.state, TransportState.unavailableHere);
      expect(byKind['transport_lora']!.state, TransportState.unavailableHere);
      expect(byKind['transport_qr']!.state, TransportState.idle);
      // Never "connected" when nothing is up.
      for (final r in rows) {
        expect(r.state, isNot(TransportState.connected));
      }
    });

    test('native idle: BLE/Nearby need devices, LoRa needs hardware', () {
      final rows = radioTransportRows(isWeb: false);
      final byKind = {for (final r in rows) r.labelKey: r};
      expect(byKind['transport_nearby']!.state, TransportState.needsDevices);
      expect(byKind['transport_ble']!.state, TransportState.needsDevices);
      expect(byKind['transport_lora']!.state, TransportState.needsHardware);
      expect(byKind['transport_qr']!.state, TransportState.idle);
    });

    test('native with a live BLE session shows connected only for BLE', () {
      final rows = radioTransportRows(isWeb: false, bleSessionOpen: true);
      final byKind = {for (final r in rows) r.labelKey: r};
      expect(byKind['transport_ble']!.state, TransportState.connected);
      // Others remain honest (not connected).
      expect(byKind['transport_nearby']!.state, TransportState.needsDevices);
      expect(byKind['transport_lora']!.state, TransportState.needsHardware);
    });

    test('native with a live LoRa link shows connected for LoRa', () {
      final rows = radioTransportRows(isWeb: false, loraLinkUp: true);
      final lora = rows.firstWhere((r) => r.labelKey == 'transport_lora');
      expect(lora.state, TransportState.connected);
    });

    test('state keys map to honest l10n keys, never fake connected', () {
      final web = radioTransportRows(isWeb: true);
      for (final r in web) {
        expect(r.stateKey, isNot('status_connected'),
            reason: '${r.labelKey} must not claim connected on web');
      }
    });

    test('tones: connected=good, unreachable=bad, others neutral', () {
      const good = TransportStatus(
          kind: TransportKind.bluetooth,
          labelKey: 'x',
          state: TransportState.connected);
      const bad = TransportStatus(
          kind: TransportKind.internet,
          labelKey: 'x',
          state: TransportState.unreachable);
      const neutral = TransportStatus(
          kind: null, labelKey: 'x', state: TransportState.needsHardware);
      expect(good.tone, StatusTone.good);
      expect(bad.tone, StatusTone.bad);
      expect(neutral.tone, StatusTone.neutral);
    });
  });
}
