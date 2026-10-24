/// What this phone can reach right now (Spec section 65). Each extra link
/// improves syncing; none of them decide whether the app works.
class NetworkStatus {
  const NetworkStatus({
    required this.internet,
    required this.peers,
    required this.node,
    required this.lora,
    required this.gatewayOnline,
    required this.lastSync,
    required this.lastGlobalSync,
    this.queued = 0,
  });

  /// This phone has its own internet connection.
  final bool internet;

  /// Other phones nearby over Bluetooth or Wi-Fi.
  final int peers;

  /// A Resilience Node is in Wi-Fi range.
  final bool node;

  /// Paired to a LoRa radio on the Meshtastic mesh.
  final bool lora;

  /// Some node on the mesh can reach AWS, so requests get checked.
  final bool gatewayOnline;

  /// Last exchange with anyone: a phone, a node or the cloud.
  final DateTime lastSync;

  /// Last exchange that reached the cloud.
  final DateTime lastGlobalSync;

  /// Items waiting on this phone for a route.
  final int queued;

  NetworkStatus copyWith({bool? internet, int? queued, DateTime? lastSync}) =>
      NetworkStatus(
        internet: internet ?? this.internet,
        peers: peers,
        node: node,
        lora: lora,
        gatewayOnline: gatewayOnline || (internet ?? false),
        lastSync: lastSync ?? this.lastSync,
        lastGlobalSync: (internet ?? false) ? DateTime.now() : lastGlobalSync,
        queued: queued ?? this.queued,
      );
}

/// The regional readiness package, downloaded before an emergency
/// (Spec section 35).
class ReadinessPackage {
  const ReadinessPackage({
    required this.region,
    required this.sizeMb,
    required this.version,
    required this.publishedAt,
    this.downloadedVersion,
    this.downloadedAt,
    this.progress,
  });

  final String region;
  final int sizeMb;
  final int version;
  final DateTime publishedAt;
  final int? downloadedVersion;
  final DateTime? downloadedAt;

  /// 0 to 1 while downloading, otherwise null.
  final double? progress;

  bool get downloading => progress != null;
  bool get updateAvailable => downloadedVersion != version;

  ReadinessPackage copyWith({
    double? progress,
    bool clearProgress = false,
    int? downloadedVersion,
    DateTime? downloadedAt,
  }) =>
      ReadinessPackage(
        region: region,
        sizeMb: sizeMb,
        version: version,
        publishedAt: publishedAt,
        downloadedVersion: downloadedVersion ?? this.downloadedVersion,
        downloadedAt: downloadedAt ?? this.downloadedAt,
        progress: clearProgress ? null : progress ?? this.progress,
      );
}
