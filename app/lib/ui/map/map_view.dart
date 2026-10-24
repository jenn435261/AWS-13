import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/strings.dart';
import '../../location/position_service.dart';
import '../theme/app_theme.dart';

/// A real, pannable, zoomable map (OpenStreetMap tiles) with markers at their
/// true coordinates.
///
/// Tiles are fetched over the internet. Offline, the markers and the user dot
/// still draw on a plain background and a banner says tiles are unavailable;
/// offline PMTiles served by a Resilience Node are the planned replacement
/// (see docs/SPEC_PROVIDER_AND_FEATURES.md, "Map").
///
/// Pass [onPick] to turn the map into a point picker: a tap reports the
/// position and shows a pin there ([picked]).
class MapView extends StatefulWidget {
  final List<MapMarker> markers;

  /// The user's own position, drawn as a dot. Null => no dot is drawn (we never
  /// invent a "you are here").
  final LatLng? me;

  /// Initial centre; defaults to [me], then the markers' centre, then
  /// [kDefaultMapCenter].
  final LatLng? center;
  final double zoom;
  final ValueChanged<LatLng>? onPick;
  final LatLng? picked;
  final VoidCallback? onLocateMe;

  const MapView({
    super.key,
    this.markers = const [],
    this.me,
    this.center,
    this.zoom = 13,
    this.onPick,
    this.picked,
    this.onLocateMe,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final _controller = MapController();
  bool _tilesFailed = false;

  LatLng get _initialCenter {
    if (widget.center != null) return widget.center!;
    if (widget.me != null) return widget.me!;
    if (widget.markers.isNotEmpty) {
      final lat = widget.markers.map((m) => m.position.latitude).reduce(
              (a, b) => a + b) /
          widget.markers.length;
      final lon = widget.markers.map((m) => m.position.longitude).reduce(
              (a, b) => a + b) /
          widget.markers.length;
      return LatLng(lat, lon);
    }
    return kDefaultMapCenter;
  }

  @override
  void didUpdateWidget(MapView old) {
    super.didUpdateWidget(old);
    // Follow the user when a new position arrives (e.g. after "locate me").
    if (widget.me != null && widget.me != old.me) {
      _controller.move(widget.me!, widget.zoom);
    }
  }

  void _zoom(double delta) {
    final cam = _controller.camera;
    _controller.move(cam.center, (cam.zoom + delta).clamp(2, 19));
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Map',
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: widget.zoom,
              minZoom: 2,
              maxZoom: 19,
              onTap: widget.onPick == null
                  ? null
                  : (_, p) => widget.onPick!(p),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'live.chrisccluk.resilience',
                maxNativeZoom: 19,
                errorTileCallback: (tile, error, stack) {
                  if (!_tilesFailed && mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _tilesFailed = true);
                    });
                  }
                },
              ),
              MarkerLayer(markers: [
                for (final m in widget.markers)
                  Marker(
                    point: m.position,
                    width: 44,
                    height: 44,
                    child: _MarkerDot(marker: m),
                  ),
                if (widget.me != null)
                  Marker(
                      point: widget.me!,
                      width: 26,
                      height: 26,
                      child: const _YouDot()),
                if (widget.picked != null)
                  Marker(
                      point: widget.picked!,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: Icon(Icons.location_on_rounded,
                          size: 44, color: scheme.error)),
              ]),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          if (_tilesFailed)
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Material(
                color: scheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(l.t('map_tiles_offline'),
                      style:
                          const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
                ),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 36,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapButton(
                    icon: Icons.add_rounded,
                    tooltip: l.t('zoom_in'),
                    onPressed: () => _zoom(1)),
                const SizedBox(height: 8),
                _MapButton(
                    icon: Icons.remove_rounded,
                    tooltip: l.t('zoom_out'),
                    onPressed: () => _zoom(-1)),
                if (widget.onLocateMe != null) ...[
                  const SizedBox(height: 8),
                  _MapButton(
                      icon: Icons.my_location_rounded,
                      tooltip: l.t('locate_me'),
                      onPressed: widget.onLocateMe!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _MapButton(
      {required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      shape: const CircleBorder(),
      child: IconButton(
          tooltip: tooltip, icon: Icon(icon), onPressed: onPressed),
    );
  }
}

class MapMarker {
  final String id;
  final IconData icon;
  final Color color;
  final LatLng position;
  final String label;
  final VoidCallback? onTap;
  const MapMarker({
    required this.id,
    required this.icon,
    required this.color,
    required this.position,
    required this.label,
    this.onTap,
  });
}

class _MarkerDot extends StatelessWidget {
  final MapMarker marker;
  const _MarkerDot({required this.marker});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: marker.onTap != null,
      label: marker.label,
      child: GestureDetector(
        onTap: marker.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: marker.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
          ),
          child: Icon(marker.icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _YouDot extends StatelessWidget {
  const _YouDot();
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'You',
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.verified,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
        ),
      ),
    );
  }
}
