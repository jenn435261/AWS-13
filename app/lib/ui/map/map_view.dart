import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../theme/app_theme.dart';

/// A platform-safe map surface.
///
/// The real MapLibre + PMTiles map is a mobile-native plugin that does not run
/// on web or in widget tests. To keep the whole app compilable as a web boot
/// gate (and testable), the map lives behind this widget: on
/// unsupported platforms it renders a schematic fallback that still shows the
/// user position and resource markers, so the map-first layout is always
/// present. On Android/iOS a later build swaps in the MapLibre implementation
/// behind the same widget contract.
class MapView extends StatelessWidget {
  /// Resource markers to plot (approximate positions in a 0..1 unit space for
  /// the schematic fallback).
  final List<MapMarker> markers;
  const MapView({super.key, this.markers = const []});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Offline map',
      child: Container(
        color: scheme.surfaceContainerHighest,
        child: Stack(
          children: [
            // Schematic "map" grid so the surface reads as a map even in the
            // fallback (web/test). Real tiles replace this on mobile.
            Positioned.fill(child: CustomPaint(painter: _GridPainter(scheme))),
            // Markers.
            ...markers.map((m) => _MarkerDot(marker: m)),
            // "You are here" center dot.
            const Center(child: _YouDot()),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(l.t('you_are_here'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MapMarker {
  final String id;
  final IconData icon;
  final Color color;
  final double x; // 0..1 fractional position
  final double y;
  final String label;
  final VoidCallback? onTap;
  const MapMarker({
    required this.id,
    required this.icon,
    required this.color,
    required this.x,
    required this.y,
    required this.label,
    this.onTap,
  });
}

class _MarkerDot extends StatelessWidget {
  final MapMarker marker;
  const _MarkerDot({required this.marker});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return Positioned(
        left: (marker.x * c.maxWidth).clamp(0, c.maxWidth - 48),
        top: (marker.y * c.maxHeight).clamp(0, c.maxHeight - 48),
        child: Semantics(
          button: marker.onTap != null,
          label: marker.label,
          child: GestureDetector(
            onTap: marker.onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: marker.color,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4)
                ],
              ),
              child: Icon(marker.icon, color: Colors.white, size: 26),
            ),
          ),
        ),
      );
    });
  }
}

class _YouDot extends StatelessWidget {
  const _YouDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: AppTheme.verified,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final ColorScheme scheme;
  _GridPainter(this.scheme);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = scheme.outline.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
