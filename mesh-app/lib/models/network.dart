/// The ways this phone can pass data on.
enum LinkKind {
  /// AWS, straight over this phone's own internet.
  cloud,

  /// A Resilience Node on local Wi-Fi.
  node,

  /// A paired LoRa radio on the Meshtastic mesh.
  lora,

  /// Phones nearby over Wi-Fi.
  wifi,

  /// Phones nearby over Bluetooth.
  bluetooth,
}

/// One link, as its transport reports it.
class LinkStatus {
  const LinkStatus({
    required this.kind,
    required this.up,
    this.peers = 0,
    this.reachesCloud = false,
    this.available = true,
    this.lastAck,
  });

  final LinkKind kind;

  /// The link can carry data right now.
  final bool up;

  /// Phones in range, for nearby links.
  final int peers;

  /// What it reaches can pass data on to AWS: a node or radio gateway with
  /// its own uplink.
  final bool reachesCloud;

  /// False when this phone can't use the link at all: no radio paired, a
  /// permission turned off, or the native side not built yet.
  final bool available;

  /// When this link last confirmed it took something.
  final DateTime? lastAck;
}

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
    this.links = const [],
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

  /// Each link on its own, when the status comes from the transports.
  final List<LinkStatus> links;

  /// The link of [kind], if the transports report one.
  LinkStatus? link(LinkKind kind) {
    for (final l in links) {
      if (l.kind == kind) return l;
    }
    return null;
  }

  /// AWS can be reached: directly, or through a node or radio gateway.
  bool get cloudReachable => internet || gatewayOnline;

  /// Something can carry data off this phone: internet, a node, LoRa or a
  /// nearby phone. With none, messages and requests wait on the phone.
  bool get hasRoute => internet || node || lora || peers > 0;

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
        links: links,
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
