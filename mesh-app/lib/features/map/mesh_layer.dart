import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/mesh_node.dart';

/// How far a radio reaches, for drawing its coverage.
const radioRangeMeters = 450.0;

/// A link between two radios, or between this phone and its nearest radio.
typedef MeshLink = (LatLng from, LatLng to, {bool weak});

/// The links the network uses: each radio to the nearest radio one hop
/// closer to the node, and this phone to the nearest radio. Radios not heard
/// lately get weak links.
List<MeshLink> meshLinks(List<MeshNode> radios, LatLng? me) {
  const distance = Distance();
  final links = <MeshLink>[];
  for (final r in radios) {
    if (r.hops == 0) continue;
    final closer = radios.where((o) => o.hops == r.hops - 1).toList();
    if (closer.isEmpty) continue;
    closer.sort((a, b) => distance(a.location!, r.location!)
        .compareTo(distance(b.location!, r.location!)));
    links.add((closer.first.location!, r.location!, weak: !r.isOnline));
  }
  if (me != null && radios.isNotEmpty) {
    final nearest = [...radios]
      ..sort((a, b) => distance(a.location!, me).compareTo(distance(b.location!, me)));
    links.insert(0, (me, nearest.first.location!, weak: false));
  }
  return links;
}

/// Each radio's reach, as a faint circle in meters.
List<CircleMarker> coverageCircles(List<MeshNode> radios, Color color) => [
      for (final r in radios)
        CircleMarker(
          point: r.location!,
          radius: radioRangeMeters,
          useRadiusInMeter: true,
          color: color.withValues(alpha: r.isOnline ? 0.07 : 0.03),
          borderColor: color.withValues(alpha: r.isOnline ? 0.35 : 0.18),
          borderStrokeWidth: 1.5,
        ),
    ];

/// The links as lines with a light edge, so they read on any street map.
/// Weak links are dashed.
List<Polyline> linkLines(List<MeshLink> links, Color color, Color edge) => [
      for (final l in links)
        Polyline(
          points: [l.$1, l.$2],
          strokeWidth: l.weak ? 2.5 : 3.5,
          color: color.withValues(alpha: l.weak ? 0.5 : 0.85),
          borderStrokeWidth: 1.5,
          borderColor: edge.withValues(alpha: 0.8),
          pattern: l.weak
              ? StrokePattern.dashed(segments: const [10, 8])
              : const StrokePattern.solid(),
        ),
    ];
