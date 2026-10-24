import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../../data/demo_area.dart';
import '../../data/map_tiles.dart';
import '../../l10n/labels.dart';
import '../../models/help.dart';
import '../../models/mesh_node.dart';
import '../../models/network.dart';
import '../../models/resource.dart';
import '../../router.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/surfaces.dart';
import '../../ui/theme.dart';
import '../../ui/visuals.dart';
import '../../utils/format.dart';
import '../more/language_screen.dart';
import '../requests/request_actions.dart';
import '../resources/add_resource_sheet.dart';
import '../resources/resource_sheet.dart';
import 'map_pins.dart';
import 'mesh_layer.dart';

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
  final _map = MapController();
  final _tiles = MapTiles();
  final _cards = PageController(viewportFraction: 0.9);
  String? _selectedId;
  bool _showFacilities = true;
  bool _showLive = true;
  bool _showRequests = true;
  bool _showRadios = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A street map in the app's light or dark look and in its language.
    _tiles.open(
      dark: Theme.of(context).brightness == Brightness.dark,
      languageCode: Localizations.localeOf(context).languageCode,
    );
  }

  @override
  void dispose() {
    _cards.dispose();
    _map.dispose();
    _tiles.dispose();
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
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final colors = AppColors.of(context).map;
    final mine = [
      for (final r in AppScope.of(context).repository.requests.value)
        if (r.mine && r.location != null && r.stage != RequestStage.resolved) r,
    ];
    final urgent = [
      for (final item in items)
        if (item case _NearbyRequest(:final request) when request.urgency == Urgency.now)
          item.point,
      for (final r in mine) r.location!,
    ];

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: offsetMeters(demoCenter, -60, 0),
        initialZoom: 16,
        minZoom: 12,
        maxZoom: 20,
        backgroundColor: colors.base,
        // Stays near the demo data around campus.
        cameraConstraint: CameraConstraint.containCenter(
          bounds: LatLngBounds(
            offsetMeters(demoCenter, -6000, -6000),
            offsetMeters(demoCenter, 6000, 6000),
          ),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (_, _) => setState(() => _selectedId = null),
        onLongPress: (_, point) => showAddResourceSheet(context, point),
      ),
      children: [
        ListenableBuilder(
          listenable: _tiles,
          builder: (context, _) {
            final style = _tiles.style;
            return style == null
                ? const SizedBox.shrink()
                : VectorTileLayer(
                    // A new key per style, so a theme or language change
                    // redraws the map instead of reusing old tiles.
                    key: ObjectKey(style),
                    theme: style.theme,
                    sprites: style.sprites,
                    tileProviders: style.providers,
                  );
          },
        ),
        if (_showRadios) ...[
          CircleLayer(circles: coverageCircles(radios, colors.mesh)),
          PolylineLayer(
            polylines: linkLines(meshLinks(radios, fix?.point), colors.mesh, c.surfaceContainerLowest),
          ),
        ],
        if (fix != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: fix.point,
                radius: fix.accuracyMeters,
                useRadiusInMeter: true,
                color: c.primary.withValues(alpha: 0.10),
                borderColor: c.primary.withValues(alpha: 0.35),
                borderStrokeWidth: 1,
              ),
            ],
          ),
        // Urgent requests pulse under their pins, so they're found first.
        MarkerLayer(
          markers: [
            for (final p in urgent)
              Marker(
                point: p,
                width: 72,
                height: 72,
                child: const IgnorePointer(child: Pulse(color: sosRed, size: 72, rings: 1)),
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            if (_showRadios)
              for (final n in radios)
                Marker(
                  point: n.location!,
                  width: RadioDot.size,
                  height: RadioDot.size,
                  child: Semantics(
                    label: n.name,
                    excludeSemantics: true,
                    child: RadioDot(node: n),
                  ),
                ),
            if (fix != null)
              Marker(
                point: fix.point,
                width: MeDot.size,
                height: MeDot.size,
                child: Semantics(
                  label: l.myLocation,
                  child: const IgnorePointer(child: MeDot()),
                ),
              ),
            for (final item in items)
              Marker(
                point: item.point,
                width: pinBox.width,
                height: pinBox.height,
                alignment: Alignment.topCenter,
                child: switch (item) {
                  _NearbyRequest(:final request) => _Tappable(
                      label: '${l.requestTitle(request)}, ${l.urgency(request.urgency)}',
                      selected: item.id == _selectedId,
                      onTap: () => _selectFromMap(item.id, items),
                      child: MapPin(
                        icon: requestIcon(request),
                        hue: requestHue(request),
                        selected: item.id == _selectedId,
                      ),
                    ),
                  _NearbyResource(:final resource) => _Tappable(
                      label: '${l.resourceTitle(resource)}, ${l.provenance(resource)}',
                      selected: item.id == _selectedId,
                      onTap: () => _selectFromMap(item.id, items),
                      child: MapPin(
                        icon: resourceIcon(resource.kind),
                        hue: resourceHue(resource.kind),
                        solid: resource.verified,
                        mark: resourceMark(context, resource),
                        selected: item.id == _selectedId,
                        faded: resource.isStale(),
                      ),
                    ),
                },
              ),
            for (final r in mine)
              Marker(
                point: r.location!,
                width: pinBox.width,
                height: pinBox.height,
                alignment: Alignment.topCenter,
                child: _Tappable(
                  label: l.requestTitle(r),
                  onTap: () => context.go(requestPath(r.id)),
                  child: MapPin(icon: requestIcon(r), hue: sosRed),
                ),
              ),
          ],
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
      // The bottom bar floats over the map; its height arrives as padding.
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: _MapCredit(tiles: _tiles),
                  ),
                ),
                const SizedBox(width: 12),
                Tooltip(
              message: l.myLocation,
              child: Glass(
                radius: 26,
                onTap: () => _focus(here),
                child: SizedBox.square(
                  dimension: 52,
                  child: Icon(Icons.my_location, color: c.primary),
                ),
              ),
            ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 16, 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: _MapCopyright(tiles: _tiles),
            ),
          ),
          SizedBox(
            height: 116,
            child: loading
                ? Skeletonizer(
                    child: _NearbyCard(
                      leading: const IconTile(icon: Icons.water_drop, color: Hues.water),
                      title: l.resWater,
                      lines: [l.verifiedOrg, l.distanceMeters(120)],
                      onTap: () {},
                    ),
                  )
                : items.isEmpty
                    ? _NearbyCard(
                        leading: IconTile(icon: Icons.touch_app_outlined, color: c.primary),
                        title: l.nothingNearby,
                        lines: [l.addHereHint],
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

    return switch (item) {
      _NearbyRequest(:final request) => _NearbyCard(
          leading: IconTile(
            icon: requestIcon(request),
            color: requestHue(request),
            solid: true,
          ),
          title: l.requestTitle(request),
          lines: [
            request.helpingIsMe ? l.youAreHelping : l.urgency(request.urgency),
            [
              l.distance(item.distance),
              l.peopleCount(request.people),
              l.timeAgo(request.createdAt),
            ].join('  ·  '),
          ],
          accent: urgencyHue(request.urgency),
          selected: item.id == _selectedId,
          onTap: () => _open(item),
          onLongPress: () => showRequestActions(
            context,
            request,
            onShowOnMap: () => _focus(item.point),
          ),
        ),
      _NearbyResource(:final resource) => _NearbyCard(
          leading: ResourceBadge(resource: resource, size: 52),
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
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          void toggle(void Function() change) {
            Haptics.tick();
            setState(change);
            setSheet(() {});
          }

          Widget layer(IconData icon, Color hue, String title, bool value, void Function(bool) set) =>
              SwitchListTile(
                secondary: IconTile(icon: icon, color: hue, size: 44),
                title: Text(title),
                value: value,
                onChanged: (v) => toggle(() => set(v)),
              );

          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(l.layers, style: Theme.of(sheet).textTheme.headlineSmall),
                ),
                layer(Icons.local_hospital_outlined, Hues.medical, l.layerFacilities,
                    _showFacilities, (v) => _showFacilities = v),
                layer(Icons.water_drop_outlined, Hues.water, l.layerLive, _showLive,
                    (v) => _showLive = v),
                layer(Icons.sos_outlined, sosRed, l.layerRequests, _showRequests,
                    (v) => _showRequests = v),
                layer(Icons.cell_tower, Theme.of(sheet).colorScheme.primary, l.layerRadios,
                    _showRadios, (v) => _showRadios = v),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.touch_app_outlined),
                  title: Text(l.addHereHint),
                ),
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: Text(l.mapSource),
                  subtitle: Text(l.mapSourceNote),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Bottom left of the map: why the street map doesn't show, if it doesn't.
class _MapCredit extends StatelessWidget {
  const _MapCredit({required this.tiles});

  final MapTiles tiles;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: tiles,
      builder: (context, _) => switch (tiles.status) {
        MapTilesStatus.ready => const SizedBox.shrink(),
        MapTilesStatus.loading => _MapChip(icon: Icons.map_outlined, text: l.mapLoading),
        MapTilesStatus.notSetUp => _MapChip(icon: Icons.map_outlined, text: l.mapNotSetUp),
        MapTilesStatus.unavailable => _MapChip(icon: Icons.cloud_off, text: l.mapOffline),
      },
    );
  }
}

/// Bottom right of the map: the map data credit, as the terms ask.
class _MapCopyright extends StatelessWidget {
  const _MapCopyright({required this.tiles});

  final MapTiles tiles;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tiles,
      builder: (context, _) => tiles.status == MapTilesStatus.ready && tiles.attribution != null
          ? _MapChip(text: tiles.attribution!)
          : const SizedBox.shrink(),
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Glass(
      radius: 14,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: c.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Connection status and alerts on the left; language
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
    final ready = network.internet || network.node || network.lora || network.peers > 0;
    final urgent = alerts.any((a) => a.urgent);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Glass(
                radius: 24,
                onTap: () => context.go('/more/network'),
                padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusIcon(internet: network.internet, ready: ready),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${network.internet ? l.statusOnline : l.statusOffline}  ·  ${l.statusReady}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
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
              ),
              if (alerts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Glass(
                  radius: 24,
                  tint: urgent ? c.errorContainer.withValues(alpha: 0.92) : null,
                  onTap: () => showAlertsSheet(context, alerts),
                  padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign, color: urgent ? c.onErrorContainer : c.primary),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          l.alertsCount(alerts.length),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: urgent ? c.onErrorContainer : null,
                          ),
                        ),
                      ),
                    ],
                  ),
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

/// The connection icon on a colored disc: green when messages can move,
/// amber when they wait on this phone.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.internet, required this.ready});

  final bool internet;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final hue = ready ? c.primary : Hues.caution;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconTile(
          icon: internet ? Icons.cloud_done_outlined : Icons.cloud_off,
          color: hue,
          size: 40,
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: ready ? const Color(0xFF2FB344) : Hues.caution,
              shape: BoxShape.circle,
              border: Border.all(color: c.surfaceContainerLowest, width: 2.5),
            ),
          ),
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
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(l.alertsTitle, style: Theme.of(sheet).textTheme.headlineSmall),
          ),
          for (final a in alerts) ...[
            Card(
              color: a.urgent ? c.errorContainer : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconTile(
                      icon: a.urgent ? Icons.warning_amber_rounded : Icons.campaign_outlined,
                      color: a.urgent ? sosRed : c.primary,
                      solid: a.urgent,
                      size: 44,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            style: Theme.of(sheet).textTheme.titleMedium?.copyWith(
                                  color: a.urgent ? c.onErrorContainer : null,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a.body,
                            style: TextStyle(color: a.urgent ? c.onErrorContainer : null),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.verified,
                                size: 18,
                                color: a.urgent ? c.onErrorContainer : c.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${a.organization}  ·  ${l.timeAgo(a.at)}',
                                  style: TextStyle(
                                    color: a.urgent ? c.onErrorContainer : c.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    ),
  );
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
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: Glass(
          radius: 26,
          onTap: onTap,
          child: SizedBox.square(
            dimension: 52,
            child: Icon(icon, color: c.onSurface),
          ),
        ),
      ),
    );
  }
}

/// A tappable map marker with a spoken label.
class _Tappable extends StatelessWidget {
  const _Tappable({
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
      child: GestureDetector(onTap: onTap, child: child),
    );
  }
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({
    required this.leading,
    required this.title,
    required this.lines,
    required this.onTap,
    this.accent,
    this.selected = false,
    this.onLongPress,
  });

  final Widget leading;
  final String title;
  final List<String> lines;

  /// A colored first line, for urgency.
  final Color? accent;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: selected ? c.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Glass(
          radius: 24,
          onTap: onTap,
          onLongPress: onLongPress,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              leading,
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
                      style: theme.textTheme.titleMedium,
                    ),
                    for (final (i, line) in lines.indexed)
                      Row(
                        children: [
                          if (i == 0 && accent != null) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              line,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: c.onSurfaceVariant,
                                fontWeight: i == 0 ? FontWeight.w600 : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.outline),
            ],
          ),
        ),
      ),
    );
  }
}
