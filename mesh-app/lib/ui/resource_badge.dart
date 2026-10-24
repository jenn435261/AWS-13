import 'package:flutter/material.dart';

import '../features/map/map_pins.dart' show TrustMark;
import '../models/resource.dart';
import 'surfaces.dart';
import 'visuals.dart';

/// A resource's icon in its kind's color. Verified places are filled and
/// carry a check, community ones are a soft tint, unconfirmed ones carry a
/// warning, and stale ones fade.
class ResourceBadge extends StatelessWidget {
  const ResourceBadge({super.key, required this.resource, this.size = 44});

  final Resource resource;
  final double size;

  @override
  Widget build(BuildContext context) {
    final r = resource;
    final mark = resourceMark(context, r);

    return Opacity(
      opacity: r.isStale() ? 0.5 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconTile(
            icon: resourceIcon(r.kind),
            color: resourceHue(r.kind),
            size: size,
            solid: r.verified,
          ),
          if (mark != null) Positioned(right: -5, bottom: -5, child: mark),
        ],
      ),
    );
  }
}

/// The trust sign for a resource: a check when verified, a warning when only
/// one person reported it, nothing for community places.
Widget? resourceMark(BuildContext context, Resource r) => r.verified
    ? TrustMark(icon: Icons.verified, color: Theme.of(context).colorScheme.primary)
    : r.confidence == Confidence.unconfirmed
        ? const TrustMark(icon: Icons.warning_amber_rounded, color: Hues.cautionInk)
        : null;
