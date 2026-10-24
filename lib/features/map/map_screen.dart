import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../data/demo_area.dart';
import '../../l10n/labels.dart';
import '../../models/help.dart';
import '../../models/mesh_node.dart';
import '../../models/network.dart';
import '../../models/resource.dart';
import '../../router.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/visuals.dart';
import '../../utils/format.dart';
import '../more/language_screen.dart';
import '../requests/request_actions.dart';
import '../resources/add_resource_sheet.dart';
import '../resources/resource_sheet.dart';

/// Something on the map that gets a card in the swipeable row.
sealed class _Nearby {
  const _Nearby(this.distance);

  final double distance;
  String get id;
  LatLng get point;
}

class _NearbyRequest extends _Nearby {
  const _NearbyRequest(this.request, super.distance);

  final HelpRequest request;
  @override
  String get id => request.id;
  @override
  LatLng get point => request.location!;
}

class _NearbyResource extends _Nearby {
  const _NearbyResource(this.resource, super.distance);

  final Resource resource;
  @override
  String get id => resource.id;
  @override
  LatLng get point => resource.location;
}

/// The front page (Spec sections 3 and 60): an offline map with resources,
/// alerts, requests, radios and you. Swipe the cards to move between nearby
/// things; tap to open one; hold a card for quick actions; hold the map to
/// add something.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static final _area = buildDemoArea();

  final _map = MapController();
  final _cards = PageController(viewportFraction: 0.9);
  String? _selectedId;
  bool _showFacilities = true;
  bool _showLive = true;
  bool _showRequests = true;
  bool _showRadios = true;

  /// Real map tiles come from OpenStreetMap. After a few failed tiles
  /// (offline), the drawn demo neighborhood is shown instead.
  int _tileErrors = 0;
  bool _tilesFailed = false;

  /// Where the map last jumped to on its own, so a new GPS fix far away
  /// (the real one replacing the demo one) recenters it once.
  LatLng? _centeredAt;

  void _onTileError() {
    if (_tilesFailed || ++_tileErrors < 4) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _tilesFailed = true);
    });
  }

  void _followFix(LocationFix? fix) {
    if (fix == null) return;
    final last = _centeredAt;
    if (last != null && metersBetween(last, fix.point) < 500) return;
    _centeredAt = fix.point;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _map.move(fix.point, max(_map.camera.zoom, 16));
      } catch (_) {
        // The map isn't laid out yet; initialCenter already covers it.
      }
    });
  }

  @override
  void dispose() {
    _cards.dispose();
    _map.dispose();
    super.dispose();
  }

  List<_Nearby> _nearby(AppScope scope, LatLng from) {
    final repo = scope.repository;
    return [
      if (_showRequests)
        for (final r in repo.requests.value)
          if (!r.mine && r.location != null && (r.isOpen || r.helpingIsMe))
            _NearbyRequest(r, metersBetween(from, r.location!)),
      for (final r in repo.resources.value)
        if (r.kind.isFacility ? _showFacilities : _showLive)
          _NearbyResource(r, metersBetween(from, r.location)),
    ]..sort((a, b) {
        // Stale information ranks lower but stays visible (Spec 10, 66).
        double rank(_Nearby n) => n.distance *
            (n is _NearbyResource && n.resource.isStale() ? 3 : 1);
        return rank(a).compareTo(rank(b));
      });
  }

  void _focus(LatLng point) {
    final zoom = max(_map.camera.zoom, 16.5);
    _map.move(point, zoom);
  }

  void _selectFromMap(String id, List<_Nearby> items) {
    Haptics.tick();
    setState(() => _selectedId = id);
    final index = items.indexWhere((i) => i.id == id);
    if (index >= 0 && _cards.hasClients) {
      _cards.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _open(_Nearby item) => switch (item) {
        _NearbyRequest(:final request) => context.go(requestPath(request.id)),
        _NearbyResource(:final resource) => showResourceSheet(context, resource.id),
      };

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;

    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([
          repo.requests,
          repo.resources,
          repo.alerts,
          repo.nodes,
          repo.location,
          repo.loading,
          repo.network,
        ]),
        builder: (context, _) {
          final fix = repo.location.value;
          final here = fix?.point ?? demoCenter;
          final items = _nearby(scope, here);
          final radios = [
            for (final n in repo.nodes.value)
              if (n.enabled && n.location != null) n,
          ];

          return Stack(
            children: [
              _buildMap(context, fix, items, radios),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _TopBar(
                    network: repo.network.value,
                    alerts: repo.alerts.value,
                    onLayers: _showLayers,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottom(context, items, here, repo.loading.value),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    LocationFix? fix,
    List<_Nearby> items,
    List<MeshNode> radios,
  ) {
    final c = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final mine = [
      for (final r in AppScope.of(context).repository.requests.value)
        if (r.mine && r.location != null && r.stage != RequestStage.resolved) r,
    ];
    final park = Color.lerp(c.surfaceContainerHigh, Colors.green, 0.28)!;
    _followFix(fix);

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: fix?.point ?? demoCenter,
        initialZoom: 16,
        minZoom: 3,
        maxZoom: 19,
        backgroundColor: c.surface,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (_, _) => setState(() => _selectedId = null),
        onLongPress: (_, point) => showAddResourceSheet(context, point),
      ),
      children: [
        if (!_tilesFailed)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.jennelledabu.mesh_app',
            errorTileCallback: (_, _, _) => _onTileError(),
          ),
        // Offline fallback: the drawn demo neighborhood.
        if (_tilesFailed)
        PolygonLayer(
          polygons: [
            for (final b in _area.blocks)
              Polygon(points: b, color: c.surfaceContainerHigh),
            for (final p in _area.parks) Polygon(points: p, color: park),
            Polygon(
              points: _area.campus,
              color: c.primaryContainer.withValues(alpha: 0.6),
              borderColor: c.primary.withValues(alpha: 0.4),
              borderStrokeWidth: 1.5,
            ),
          ],
        ),
        if (_tilesFailed)
        PolylineLayer(
          polylines: [
            for (final road in _area.mainRoads)
              Polyline(points: road, strokeWidth: 9, color: c.secondaryContainer),
          ],
        ),
        if (_showRadios)
          CircleLayer(
            circles: [
              for (final n in radios)
                CircleMarker(
                  point: n.location!,
                  radius: 450,
                  useRadiusInMeter: true,
                  color: c.tertiary.withValues(alpha: 0.06),
                  borderColor: c.tertiary.withValues(alpha: 0.3),
                  borderStrokeWidth: 1,
                ),
            ],
          ),
        if (fix != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: fix.point,
                radius: fix.accuracyMeters,
                useRadiusInMeter: true,
                color: c.primary.withValues(alpha: 0.15),
                borderColor: c.primary.withValues(alpha: 0.4),
                borderStrokeWidth: 1,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (_showRadios)
              for (final n in radios)
                Marker(
                  point: n.location!,
                  width: 32,
                  height: 32,
                  child: _MapPin(
                    label: n.name,
                    child: _Dot(
                      icon: Icons.cell_tower,
                      background: c.secondary,
                      foreground: c.onSecondary,
                      size: 32,
                    ),
                  ),
                ),
            for (final item in items)
              Marker(
                point: item.point,
                width: 56,
                height: 56,
                child: switch (item) {
                  _NearbyRequest(:final request) => _MapPin(
                      label: '${l.requestTitle(request)}, ${l.urgency(request.urgency)}',
                      selected: item.id == _selectedId,
                      onTap: () => _selectFromMap(item.id, items),
                      child: _Dot(
                        icon: requestIcon(request),
                        background: urgencyColors(request.urgency, c).$1,
                        foreground: urgencyColors(request.urgency, c).$2,
                      ),
                    ),
                  _NearbyResource(:final resource) => _MapPin(
                      label: '${l.resourceTitle(resource)}, ${l.provenance(resource)}',
                      selected: item.id == _selectedId,
                      onTap: () => _selectFromMap(item.id, items),
                      child: ResourceBadge(resource: resource),
                    ),
                },
              ),
            for (final r in mine)
              Marker(
                point: r.location!,
                width: 56,
                height: 56,
                child: _MapPin(
                  label: l.requestTitle(r),
                  onTap: () => context.go(requestPath(r.id)),
                  child: _Dot(
                    icon: requestIcon(r),
                    background: sosRed,
                    foreground: Colors.white,
                    ring: c.primary,
                  ),
                ),
              ),
            if (fix != null)
              Marker(
                point: fix.point,
                width: 24,
                height: 24,
                child: Semantics(
                  label: l.myLocation,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.surface, width: 3),
                      boxShadow: const [
                        BoxShadow(blurRadius: 4, color: Colors.black26),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        // OpenStreetMap requires visible credit. Sits above the card row.
        if (!_tilesFailed)
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 172),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    '\u00A9 OpenStreetMap',
                    style: TextStyle(fontSize: 16, color: c.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottom(
    BuildContext context,
    List<_Nearby> items,
    LatLng here,
    bool loading,
  ) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;

    return Padding(
      // Leaves room for the Help button, which sits over the bar's edge.
      padding: const EdgeInsets.only(bottom: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 8),
            child: FloatingActionButton.small(
              heroTag: 'recenter',
              tooltip: l.myLocation,
              onPressed: () {
                Haptics.tick();
                _focus(here);
              },
              child: const Icon(Icons.my_location),
            ),
          ),
          SizedBox(
            height: 112,
            child: loading
                ? Skeletonizer(
                    child: _NearbyCard(
                      icon: Icons.water_drop,
                      title: l.resWater,
                      lines: [l.verifiedOrg, l.distanceMeters(120)],
                      colors: (Colors.grey, Colors.white),
                      onTap: () {},
                    ),
                  )
                : items.isEmpty
                    ? _NearbyCard(
                        icon: Icons.touch_app_outlined,
                        title: l.nothingNearby,
                        lines: [l.addHereHint],
                        colors: (c.secondaryContainer, c.onSecondaryContainer),
                        onTap: () {},
                      )
                    : PageView.builder(
                        controller: _cards,
                        itemCount: items.length,
                        onPageChanged: (i) {
                          Haptics.tick();
                          setState(() => _selectedId = items[i].id);
                          _focus(items[i].point);
                        },
                        itemBuilder: (context, i) => _buildCard(context, items[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, _Nearby item) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;

    return switch (item) {
      _NearbyRequest(:final request) => _NearbyCard(
          icon: requestIcon(request),
          title: l.requestTitle(request),
          lines: [
            request.helpingIsMe ? l.youAreHelping : l.urgency(request.urgency),
            [
              l.distance(item.distance),
              l.peopleCount(request.people),
              l.timeAgo(request.createdAt),
            ].join('  ·  '),
          ],
          colors: urgencyColors(request.urgency, c),
          selected: item.id == _selectedId,
          onTap: () => _open(item),
          onLongPress: () => showRequestActions(
            context,
            request,
            onShowOnMap: () => _focus(item.point),
          ),
        ),
      _NearbyResource(:final resource) => _NearbyCard(
          icon: resourceIcon(resource.kind),
          title: l.resourceTitle(resource),
          lines: [
            l.provenance(resource),
            [
              l.distance(item.distance),
              resource.isStale()
                  ? l.staleWarning(l.timeAgo(resource.lastObserved))
                  : l.timeAgo(resource.lastObserved),
            ].join('  ·  '),
          ],
          leading: ResourceBadge(resource: resource, size: 52),
          colors: (c.primary, c.onPrimary),
          selected: item.id == _selectedId,
          onTap: () => _open(item),
          onLongPress: () => showResourceSheet(context, resource.id),
        ),
    };
  }

  void _showLayers() {
    Haptics.tick();
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          void toggle(void Function() change) {
            Haptics.tick();
            setState(change);
            setSheet(() {});
          }

          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: Text(l.layers, style: Theme.of(sheet).textTheme.titleLarge),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.local_hospital_outlined),
                  title: Text(l.layerFacilities),
                  value: _showFacilities,
                  onChanged: (v) => toggle(() => _showFacilities = v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.water_drop_outlined),
                  title: Text(l.layerLive),
                  value: _showLive,
                  onChanged: (v) => toggle(() => _showLive = v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.sos_outlined),
                  title: Text(l.layerRequests),
                  value: _showRequests,
                  onChanged: (v) => toggle(() => _showRequests = v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.cell_tower),
                  title: Text(l.layerRadios),
                  value: _showRadios,
                  onChanged: (v) => toggle(() => _showRadios = v),
                ),
                ListTile(
                  leading: const Icon(Icons.touch_app_outlined),
                  title: Text(l.addHereHint),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l.demoMap),
                  subtitle: Text(l.demoMapNote),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Connection status, alerts and the demo-map notice on the left; language
/// and layers on the right.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.network,
    required this.alerts,
    required this.onLayers,
  });

  final NetworkStatus network;
  final List<EmergencyAlert> alerts;
  final VoidCallback onLayers;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Pill(
                onTap: () => context.go('/more/network'),
                children: [
                  Icon(network.internet ? Icons.cloud_done_outlined : Icons.cloud_off),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${network.internet ? l.statusOnline : l.statusOffline}  ·  ${l.statusReady}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          l.lastSyncAgo(l.timeAgo(network.lastSync)),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (alerts.isNotEmpty) ...[
                const SizedBox(height: 8),
                _Pill(
                  color: alerts.any((a) => a.urgent) ? c.errorContainer : null,
                  onTap: () => showAlertsSheet(context, alerts),
                  children: [
                    const Icon(Icons.campaign_outlined),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        l.alertsCount(alerts.length),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            _RoundButton(
              icon: Icons.translate,
              tooltip: l.language,
              onTap: () => showLanguageSheet(context),
            ),
            const SizedBox(height: 8),
            _RoundButton(icon: Icons.layers_outlined, tooltip: l.layers, onTap: onLayers),
          ],
        ),
      ],
    );
  }
}

/// Verified notices, newest first, each with its signing organization.
Future<void> showAlertsSheet(BuildContext context, List<EmergencyAlert> alerts) {
  Haptics.tick();
  final l = AppLocalizations.of(context);
  final c = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(l.alertsTitle, style: Theme.of(sheet).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final a in alerts)
            Card(
              color: a.urgent ? c.errorContainer : null,
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: Icon(
                  a.urgent ? Icons.warning_amber : Icons.campaign_outlined,
                  color: a.urgent ? c.onErrorContainer : c.primary,
                ),
                title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${a.body}\n${l.verifiedOrg}: ${a.organization}  ·  ${l.timeAgo(a.at)}',
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.children, required this.onTap, this.color});

  final List<Widget> children;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Theme.of(context).colorScheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Haptics.tick();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.surface,
      elevation: 2,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: c.onSurface),
      ),
    );
  }
}

/// A tappable map marker with a spoken label.
class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.label,
    required this.child,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final Widget child;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: onTap != null,
      selected: selected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          child: AnimatedScale(
            scale: selected ? 1.25 : 1,
            duration: const Duration(milliseconds: 200),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.icon,
    required this.background,
    required this.foreground,
    this.ring,
    this.size = 44,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? ring;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(
          color: ring ?? Theme.of(context).colorScheme.surface,
          width: 3,
        ),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
      child: Icon(icon, color: foreground, size: size * 0.5),
    );
  }
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({
    required this.icon,
    required this.title,
    required this.lines,
    required this.colors,
    required this.onTap,
    this.leading,
    this.selected = false,
    this.onLongPress,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final (Color, Color) colors;
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        elevation: 3,
        color: c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: selected ? BorderSide(color: c.primary, width: 2) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress == null
              ? null
              : () {
                  Haptics.success();
                  onLongPress!();
                },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                leading ??
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: colors.$1,
                      foregroundColor: colors.$2,
                      child: Icon(icon, size: 28),
                    ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      for (final line in lines)
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: c.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
