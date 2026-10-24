import 'package:flutter/foundation.dart' show kIsWeb;

import 'transport.dart';

/// Honest availability of a transport row in Network Status (spec §6.4 / §65).
///
/// The cardinal rule: NEVER claim a transport is up when it is not. A transport
/// that cannot exist on this platform (BLE / LoRa / Nearby on web, or a plugin/
/// radio that is absent) reports [unavailableHere]; one that exists but is not
/// currently carrying traffic reports [idle]; only a transport with a live
/// session reports [connected]. [lastActivity] carries a truthful timestamp
/// when known.
enum TransportState {
  /// Not possible on this platform / no plugin / no hardware here.
  unavailableHere,

  /// Available but currently doing nothing.
  idle,

  /// A session is currently open and usable.
  connected,

  /// Not available because real devices/hardware are required and none present.
  needsDevices,

  /// Not available because dedicated radio hardware is required and absent.
  needsHardware,

  /// Reachable/healthy (used for Cloud/Node probes).
  reachable,

  /// Known to be unreachable right now.
  unreachable,

  /// We have not determined the state yet.
  unknown,
}

/// A single Network Status row describing one transport honestly.
class TransportStatus {
  const TransportStatus({
    required this.kind,
    required this.labelKey,
    required this.state,
    this.detailKey,
    this.lastActivityMs,
  });

  /// The medium this row describes (null for QR, which is not a live radio).
  final TransportKind? kind;

  /// l10n key for the row's display name.
  final String labelKey;

  /// The honest state.
  final TransportState state;

  /// Optional l10n key for an extra detail (e.g. a named node).
  final String? detailKey;

  /// Epoch millis of the last observed activity, if any.
  final int? lastActivityMs;

  /// The l10n key for the state label.
  String get stateKey {
    switch (state) {
      case TransportState.unavailableHere:
        return 'status_unavailable_here';
      case TransportState.idle:
        return 'status_idle';
      case TransportState.connected:
        return 'status_connected';
      case TransportState.needsDevices:
        return 'status_needs_devices';
      case TransportState.needsHardware:
        return 'status_needs_hardware';
      case TransportState.reachable:
        return 'status_reachable';
      case TransportState.unreachable:
        return 'status_unreachable';
      case TransportState.unknown:
        return 'status_checking';
    }
  }

  /// A coarse tone for colouring: good / bad / neutral.
  StatusTone get tone {
    switch (state) {
      case TransportState.connected:
      case TransportState.reachable:
        return StatusTone.good;
      case TransportState.unreachable:
        return StatusTone.bad;
      case TransportState.unavailableHere:
      case TransportState.idle:
      case TransportState.needsDevices:
      case TransportState.needsHardware:
      case TransportState.unknown:
        return StatusTone.neutral;
    }
  }
}

enum StatusTone { good, bad, neutral }

/// Builds the honest radio-transport rows (Nearby, BLE, LoRa, QR) for the given
/// platform. Cloud and Node rows are driven by live probes in the screen; this
/// helper only owns the transports whose availability is a pure function of the
/// platform and whether a session is live.
///
/// * On web, Nearby / BLE / LoRa are [TransportState.unavailableHere] because
///   the browser has no access to those radios.
/// * On native, with no live session and no paired radio present, Nearby and
///   BLE report [needsDevices] (they require a second real device) and LoRa
///   reports [needsHardware] (it requires a Meshtastic radio). This is honest:
///   the code paths exist, but nothing is connected here.
/// * QR transfer is never a live radio; it is always available (it is just the
///   camera + screen) and reported as [idle] unless a transfer just happened.
List<TransportStatus> radioTransportRows({
  bool isWeb = kIsWeb,
  bool bleSessionOpen = false,
  int? bleLastActivityMs,
  bool nearbySessionOpen = false,
  int? nearbyLastActivityMs,
  bool loraLinkUp = false,
  int? loraLastActivityMs,
  int? qrLastActivityMs,
}) {
  TransportState radio(bool sessionOpen, TransportState absent) {
    if (isWeb) return TransportState.unavailableHere;
    if (sessionOpen) return TransportState.connected;
    return absent;
  }

  return <TransportStatus>[
    TransportStatus(
      kind: TransportKind.localWifi,
      labelKey: 'transport_nearby',
      state: radio(nearbySessionOpen, TransportState.needsDevices),
      lastActivityMs: nearbyLastActivityMs,
    ),
    TransportStatus(
      kind: TransportKind.bluetooth,
      labelKey: 'transport_ble',
      state: radio(bleSessionOpen, TransportState.needsDevices),
      lastActivityMs: bleLastActivityMs,
    ),
    TransportStatus(
      kind: TransportKind.meshtastic,
      labelKey: 'transport_lora',
      state: isWeb
          ? TransportState.unavailableHere
          : (loraLinkUp
              ? TransportState.connected
              : TransportState.needsHardware),
      lastActivityMs: loraLastActivityMs,
    ),
    TransportStatus(
      kind: null,
      labelKey: 'transport_qr',
      // QR is always usable on any device with a camera + screen; on web the
      // camera may still work, so we do not mark it unavailable there.
      state: TransportState.idle,
      lastActivityMs: qrLastActivityMs,
    ),
  ];
}
