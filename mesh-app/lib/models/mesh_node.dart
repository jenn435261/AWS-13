import 'package:latlong2/latlong.dart';

/// A radio on the mesh, as last reported.
class MeshNode {
  const MeshNode({
    required this.id,
    required this.name,
    required this.lastHeard,
    this.battery,
    this.rssi,
    this.snr,
    this.hops = 0,
    this.enabled = true,
    this.location,
  });

  final String id;
  final String name;
  final DateTime lastHeard;

  /// Battery percentage, or null if unknown / externally powered.
  final int? battery;

  /// Signal strength in dBm.
  final int? rssi;

  /// Signal-to-noise ratio in dB.
  final double? snr;

  /// How many relays the last packet passed through (0 = heard directly).
  final int hops;

  final bool enabled;

  /// Where the radio is installed, if known. Used to draw coverage on the map.
  final LatLng? location;

  bool get isOnline =>
      DateTime.now().difference(lastHeard) < const Duration(minutes: 15);

  MeshNode copyWith({
    String? name,
    DateTime? lastHeard,
    int? battery,
    int? rssi,
    double? snr,
    int? hops,
    bool? enabled,
  }) =>
      MeshNode(
        id: id,
        name: name ?? this.name,
        lastHeard: lastHeard ?? this.lastHeard,
        battery: battery ?? this.battery,
        rssi: rssi ?? this.rssi,
        snr: snr ?? this.snr,
        hops: hops ?? this.hops,
        enabled: enabled ?? this.enabled,
        location: location,
      );
}
