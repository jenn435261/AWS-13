import 'package:flutter/foundation.dart';

import '../../models/envelope.dart';
import '../../models/network.dart';
import 'mesh_transport.dart';

/// Picks the route for each envelope from the links that are up.
///
/// AWS first (it reaches everyone and checks requests), then a Resilience
/// Node. Urgent items go over LoRa before nearby phones, since the mesh
/// reaches further; everything else prefers the faster nearby links and
/// leaves LoRa's little airtime to what matters.
class TransportRouter {
  TransportRouter(List<MeshTransport> transports)
      : transports = List.unmodifiable(transports);

  final List<MeshTransport> transports;

  static const _urgent = [
    LinkKind.cloud,
    LinkKind.node,
    LinkKind.lora,
    LinkKind.wifi,
    LinkKind.bluetooth,
  ];
  static const _other = [
    LinkKind.cloud,
    LinkKind.node,
    LinkKind.wifi,
    LinkKind.bluetooth,
    LinkKind.lora,
  ];

  /// Fires whenever any link changes.
  late final Listenable changes =
      Listenable.merge([for (final t in transports) t.status]);

  /// Up routes that take [envelope], best first, leaving out [skip].
  List<MeshTransport> routesFor(
    Envelope envelope, {
    Set<MeshTransport> skip = const {},
  }) {
    final order =
        envelope.priority == SendPriority.urgent ? _urgent : _other;
    final up = [
      for (final t in transports)
        if (t.status.value.up && !skip.contains(t) && t.accepts(envelope)) t,
    ]..sort((a, b) => order.indexOf(a.kind).compareTo(order.indexOf(b.kind)));
    return up;
  }

  MeshTransport? transportFor(LinkKind kind) {
    for (final t in transports) {
      if (t.kind == kind) return t;
    }
    return null;
  }

  /// The network as the screens see it, built from the links.
  NetworkStatus status({
    required int queued,
    required DateTime lastSync,
    required DateTime lastGlobalSync,
    Map<LinkKind, DateTime> lastAcks = const {},
  }) {
    final links = [
      for (final t in transports)
        LinkStatus(
          kind: t.kind,
          up: t.status.value.up,
          peers: t.status.value.peers,
          reachesCloud: t.status.value.reachesCloud,
          available: t.status.value.available,
          lastAck: lastAcks[t.kind] ?? t.status.value.lastAck,
        ),
    ];
    bool up(LinkKind k) => links.any((l) => l.kind == k && l.up);
    final internet = up(LinkKind.cloud);
    return NetworkStatus(
      internet: internet,
      peers: links
          .where((l) =>
              l.up && (l.kind == LinkKind.wifi || l.kind == LinkKind.bluetooth))
          .fold(0, (sum, l) => sum + l.peers),
      node: up(LinkKind.node),
      lora: up(LinkKind.lora),
      gatewayOnline: internet || links.any((l) => l.up && l.reachesCloud),
      lastSync: lastSync,
      lastGlobalSync: lastGlobalSync,
      queued: queued,
      links: links,
    );
  }

  void dispose() {
    for (final t in transports) {
      t.dispose();
    }
  }
}
