import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../data/demo_area.dart';
import '../../data/offline_map.dart';
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
import '../more/language_screen.dart';
import '../requests/request_actions.dart';
import '../resources/add_resource_sheet.dart';
import '../resources/resource_sheet.dart';
import 'map_pins.dart';
import 'mesh_layer.dart';
import 'nearby.dart';
import 'set_location_screen.dart';
import 'street_map.dart';

/// How much of the screen's width one card takes; the next one peeks in.
const _cardFraction = 0.9;

/// The front page (Spec sections 3 and 60): an offline map with resources,
/// alerts, requests, radios and you. The cards lead with the people nearby
/// who need help. Swipe the cards to move between nearby things; tap to open
/// one; hold a card for quick actions. Tap Add here, or hold the map, to add
/// something.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with StreetMapHost {
  final _map = MapController();
  final _cards = PageController(viewportFraction: _cardFraction);
  String? _selectedId;

  /// Where a new resource is going, while its sheet is open.
  LatLng? _adding;
  bool _showFacilities = true;
  bool _showLive = true;
  bool _showRequests = true;
  bool _showRadios = true;

  @override
  void dispose() {
    _cards.dispose();
    _map.dispose();
    super.dispose();
  }

  void _focus(LatLng point) {
    final zoom = max(_map.camera.zoom, 16.5);
    _map.move(point, zoom);
  }

  void _selectFromMap(String id, List<Nearby> items) {
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

  // The request screen lives under More; pushing it keeps Back on the map.
  void _open(Nearby item) => switch (item) {
    NearbyRequest(:final request) => context.push(requestPath(request.id)),
    NearbyResource(:final resource) => showResourceSheet(context, resource.id),
  };

  Future<void> _setLocation() async {
    final repo = AppScope.of(context).repository;
    final before = repo.location.value;
    await openSetLocation(context, start: _map.camera.center);
    final fix = repo.location.value;
    if (mounted && fix != null && fix != before) _focus(fix.point);
  }

  /// With no fix, "My location" asks where you are instead of guessing.
  void _myLocation(LocationFix? fix) =>
      fix == null ? _setLocation() : _focus(fix.point);

  Future<void> _addAt(LatLng point) async {
    setState(() => _adding = point);
    await showAddResourceSheet(context, point);
    if (mounted) setState(() => _adding = null);
  }

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
          // Without a fix, cards are ordered from the area's center but
          // show no distances, and "My location" never jumps there.
          final items = nearbyItems(
            requests: repo.requests.value,
            resources: repo.resources.value,
            from: fix?.point ?? demoCenter,
            showRequests: _showRequests,
            showFacilities: _showFacilities,
            showLive: _showLive,
          );
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
                child: _buildBottom(context, items, fix, repo.loading.value),
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
    List<Nearby> items,
    List<MeshNode> radios,
  ) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final colors = AppColors.of(context).map;
    final manual = fix?.source == LocationSource.manual;
    final mine = [
      for (final r in AppScope.of(context).repository.requests.value)
        if (r.mine && r.location != null && r.stage != RequestStage.resolved) r,
    ];
    final urgent = [
      for (final item in items)
        if (item case NearbyRequest(
          :final request,
        ) when request.urgency == Urgency.now)
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
        onLongPress: (_, point) => _addAt(point),
      ),
      children: [
        StreetMapLayer(tiles: tiles),
        if (_showRadios) ...[
          CircleLayer(circles: coverageCircles(radios, colors.mesh)),
          PolylineLayer(
            polylines: linkLines(
              meshLinks(radios, fix?.point),
              colors.mesh,
              c.surfaceContainerLowest,
            ),
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
                child: const IgnorePointer(
                  child: Pulse(color: sosRed, size: 72, rings: 1),
                ),
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
                  // Its own node, so the label is not glued to the map's.
                  container: true,
                  label:
                      manual
                          ? '${l.mapYouAreHere}, ${l.mapSetByYou}'
                          : l.mapYouAreHere,
                  child: IgnorePointer(child: MeDot(live: !manual)),
                ),
              ),
            for (final item in items)
              Marker(
                point: item.point,
                width: pinBox.width,
                height: pinBox.height,
                alignment: Alignment.topCenter,
                child: switch (item) {
                  NearbyRequest(:final request) => _Tappable(
                    label:
                        '${l.requestTitle(request)}, ${l.urgency(request.urgency)}',
                    selected: item.id == _selectedId,
                    onTap: () => _selectFromMap(item.id, items),
                    child: MapPin(
                      icon: requestIcon(request),
                      hue: requestHue(request),
                      selected: item.id == _selectedId,
                    ),
                  ),
                  NearbyResource(:final resource) => _Tappable(
                    label:
                        '${l.resourceTitle(resource)}, ${l.provenance(resource)}',
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
                  onTap: () => context.push(requestPath(r.id)),
                  child: MapPin(icon: requestIcon(r), hue: sosRed),
                ),
              ),
            if (_adding != null)
              Marker(
                point: _adding!,
                width: pinBox.width,
                height: pinBox.height,
                alignment: Alignment.topCenter,
                child: IgnorePointer(
                  child: MapPin(
                    icon: Icons.add,
                    hue: c.primary,
                    selected: true,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottom(
    BuildContext context,
    List<Nearby> items,
    LocationFix? fix,
    bool loading,
  ) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final manual = fix?.source == LocationSource.manual;
    final cards =
        loading
            ? [
              _CardSpec(
                leading: const IconTile(
                  icon: Icons.water_drop,
                  color: Hues.water,
                ),
                title: l.resWater,
                lines: [l.verifiedOrg, l.distanceMeters(120)],
              ),
            ]
            : items.isEmpty
            ? [
              _CardSpec(
                leading: IconTile(
                  icon: Icons.add_location_alt_outlined,
                  color: c.primary,
                ),
                title: l.nothingNearby,
                lines: [l.mapAddEmpty],
                onTap: () => _addAt(_map.camera.center),
              ),
            ]
            : [
              for (final item in items)
                _cardFor(context, item, knowsWhere: fix != null),
            ];

    final screenHeight = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      // Never taller than the screen, or the location chip slides off the top.
      constraints: BoxConstraints(
        maxHeight: max(240, screenHeight - MediaQuery.paddingOf(context).top),
      ),
      child: Padding(
        // The bottom bar floats over the map; its height arrives as padding.
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 6,
        ),
        child: ListView(
          shrinkWrap: true,
          primary: false,
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (fix == null)
                          MapChip(
                            icon: Icons.edit_location_alt_outlined,
                            text: l.mapSetLocation,
                            emphasis: true,
                            onTap: _setLocation,
                          )
                        else if (manual)
                          MapChip(
                            icon: Icons.where_to_vote_outlined,
                            text:
                                fix.label.isEmpty
                                    ? l.mapSetByYou
                                    : l.mapSetByYouNamed(fix.label),
                            onTap: _setLocation,
                            hint: l.mapSetLocation,
                          ),
                        if (fix == null || manual) const SizedBox(height: 8),
                        StreetMapStatus(tiles: tiles),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.45,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AddHereButton(onTap: () => _addAt(_map.camera.center)),
                        const SizedBox(height: 10),
                        _RoundButton(
                          icon:
                              fix == null
                                  ? Icons.location_searching
                                  : Icons.my_location,
                          color: c.primary,
                          tooltip:
                              fix == null ? l.mapSetLocation : l.myLocation,
                          onTap: () => _myLocation(fix),
                          // Hold to set the location by hand, even with GPS.
                          onLongPress: _setLocation,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 16, 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: StreetMapCredit(tiles: tiles),
              ),
            ),
            // The card row hides while the add sheet is open. A request titled
            // "Water" would otherwise be a second "Water" next to the kind list.
            // The strip stays short so a hold on the map still lands on the map;
            // a card that needs more room scrolls instead of being cut off.
            LayoutBuilder(
              builder: (context, constraints) {
                if (_adding != null) return const SizedBox(height: 8);
                final width = constraints.maxWidth * _cardFraction;
                final natural = cards
                    .map(
                      (spec) =>
                          _NearbyCard.heightFor(context, spec, width: width),
                    )
                    .reduce(max);
                final cap = min(
                  constraints.maxHeight,
                  max(96.0, screenHeight * 0.22),
                );
                final shown = min(natural, cap);
                Widget strip(double height) => SizedBox(
                  height: height,
                  child:
                      loading
                          ? Skeletonizer(
                            child: Center(
                              child: SizedBox(
                                width: width,
                                child: _NearbyCard(cards.single),
                              ),
                            ),
                          )
                          : items.isEmpty
                          ? Center(
                            child: SizedBox(
                              width: width,
                              child: _NearbyCard(cards.single),
                            ),
                          )
                          : PageView.builder(
                            controller: _cards,
                            itemCount: items.length,
                            onPageChanged: (i) {
                              Haptics.tick();
                              setState(() => _selectedId = items[i].id);
                              _focus(items[i].point);
                            },
                            itemBuilder: (context, i) => _NearbyCard(cards[i]),
                          ),
                );
                final view = strip(natural);
                if (natural <= shown + 1) return view;
                return SizedBox(
                  height: shown,
                  child: SingleChildScrollView(child: view),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  _CardSpec _cardFor(
    BuildContext context,
    Nearby item, {
    required bool knowsWhere,
  }) {
    final l = AppLocalizations.of(context);
    final distance =
        knowsWhere ? [l.distance(item.distance)] : const <String>[];

    return switch (item) {
      NearbyRequest(:final request) => _CardSpec(
        leading: IconTile(
          icon: requestIcon(request),
          color: requestHue(request),
          solid: true,
        ),
        title: l.requestTitle(request),
        lines: [
          request.helpingIsMe ? l.youAreHelping : l.urgency(request.urgency),
          [
            ...distance,
            l.peopleCount(request.people),
            l.timeAgo(request.createdAt),
          ].join('  ·  '),
        ],
        accent: urgencyHue(request.urgency),
        selected: item.id == _selectedId,
        onTap: () => _open(item),
        onLongPress:
            () => showRequestActions(
              context,
              request,
              onShowOnMap: () => _focus(item.point),
            ),
      ),
      NearbyResource(:final resource) => _CardSpec(
        leading: ResourceBadge(resource: resource, size: 52),
        title: l.resourceTitle(resource),
        lines: [
          l.provenance(resource),
          [
            ...distance,
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
    final screen = MediaQuery.sizeOf(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Keep the sheet below the top of the screen, so a tap there dismisses
      // it. A full-height sheet would swallow that tap.
      constraints: BoxConstraints(
        maxWidth: screen.width,
        maxHeight: max(240, screen.height - 80),
      ),
      builder:
          (sheet) => StatefulBuilder(
            builder: (sheet, setSheet) {
              void toggle(void Function() change) {
                Haptics.tick();
                setState(change);
                setSheet(() {});
              }

              Widget layer(
                IconData icon,
                Color hue,
                String title,
                bool value,
                void Function(bool) set,
              ) => SwitchListTile(
                secondary: IconTile(icon: icon, color: hue, size: 44),
                title: Text(title),
                value: value,
                onChanged: (v) => toggle(() => set(v)),
              );

              void then(VoidCallback action) {
                Navigator.pop(sheet);
                action();
              }

              final saved = offlineMap.info;
              return SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        l.layers,
                        style: Theme.of(sheet).textTheme.headlineSmall,
                      ),
                    ),
                    layer(
                      Icons.local_hospital_outlined,
                      Hues.medical,
                      l.layerFacilities,
                      _showFacilities,
                      (v) => _showFacilities = v,
                    ),
                    layer(
                      Icons.water_drop_outlined,
                      Hues.water,
                      l.layerLive,
                      _showLive,
                      (v) => _showLive = v,
                    ),
                    layer(
                      Icons.sos_outlined,
                      sosRed,
                      l.layerRequests,
                      _showRequests,
                      (v) => _showRequests = v,
                    ),
                    layer(
                      Icons.cell_tower,
                      Theme.of(sheet).colorScheme.primary,
                      l.layerRadios,
                      _showRadios,
                      (v) => _showRadios = v,
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.edit_location_alt_outlined),
                      title: Text(l.mapSetLocation),
                      subtitle: Text(l.mapSetLocationSub),
                      onTap: () => then(_setLocation),
                    ),
                    ListTile(
                      leading: const Icon(Icons.add_location_alt_outlined),
                      title: Text(l.mapAddHint),
                      onTap: () => then(() => _addAt(_map.camera.center)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.download_for_offline_outlined),
                      title: Text(l.mapOfflineTitle),
                      subtitle: Text(
                        saved == null
                            ? l.mapOfflineAbout
                            : l.mapOfflineOnPhone(
                              megabytes(l, saved.sizeBytes),
                              l.timeAgo(saved.downloadedAt),
                            ),
                      ),
                      onTap: () => then(() => context.push('/more/downloads')),
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

/// The visible alternative to holding the map: adds something at the
/// center of what the map shows.
class _AddHereButton extends StatelessWidget {
  const _AddHereButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: l.mapAddHere,
      excludeSemantics: true,
      child: Glass(
        radius: 26,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.add_location_alt_outlined, color: c.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.mapAddHere,
                style: TextStyle(color: c.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Connection status and alerts on the left; language
/// and layers on the right. Text wraps rather than being cut off.
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
    final urgent = alerts.any((a) => a.urgent);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Glass(
                radius: 24,
                // Network status lives under More; Back returns to the map.
                onTap: () => context.push('/more/network'),
                padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusIcon(
                      internet: network.internet,
                      ready: network.hasRoute,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${network.internet ? l.statusOnline : l.statusOffline}  ·  ${l.statusReady}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            l.lastSyncAgo(l.timeAgo(network.lastSync)),
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
                  tint:
                      urgent ? c.errorContainer.withValues(alpha: 0.92) : null,
                  onTap: () => showAlertsSheet(context, alerts),
                  padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.campaign,
                        color: urgent ? c.onErrorContainer : c.primary,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          l.alertsCount(alerts.length),
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
            _RoundButton(
              icon: Icons.layers_outlined,
              tooltip: l.layers,
              onTap: onLayers,
            ),
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
Future<void> showAlertsSheet(
  BuildContext context,
  List<EmergencyAlert> alerts,
) {
  Haptics.tick();
  final l = AppLocalizations.of(context);
  final c = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder:
        (sheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  l.alertsTitle,
                  style: Theme.of(sheet).textTheme.headlineSmall,
                ),
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
                          icon:
                              a.urgent
                                  ? Icons.warning_amber_rounded
                                  : Icons.campaign_outlined,
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
                                style: Theme.of(
                                  sheet,
                                ).textTheme.titleMedium?.copyWith(
                                  color: a.urgent ? c.onErrorContainer : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                a.body,
                                style: TextStyle(
                                  color: a.urgent ? c.onErrorContainer : null,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.verified,
                                    size: 18,
                                    color:
                                        a.urgent
                                            ? c.onErrorContainer
                                            : c.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${a.organization}  ·  ${l.timeAgo(a.at)}',
                                      style: TextStyle(
                                        color:
                                            a.urgent
                                                ? c.onErrorContainer
                                                : c.onSurfaceVariant,
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
    this.onLongPress,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? color;

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
          onLongPress: onLongPress,
          child: SizedBox.square(
            dimension: 52,
            child: Icon(icon, color: color ?? c.onSurface),
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

/// What one card shows and does. Kept apart from the card so the row can be
/// measured before it is built.
class _CardSpec {
  const _CardSpec({
    required this.leading,
    required this.title,
    required this.lines,
    this.accent,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  final Widget leading;
  final String title;
  final List<String> lines;

  /// A colored first line, for urgency.
  final Color? accent;
  final bool selected;

  /// Null for a card that only shows something, like the loading skeleton.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard(this.spec);

  final _CardSpec spec;

  static const _outer = EdgeInsets.fromLTRB(6, 2, 6, 10);
  static const _border = 2.0;
  static const _padding = 14.0;
  static const _leading = 52.0;
  static const _gap = 14.0;
  static const _chevron = 24.0;
  static const _dot = 8.0 + 6.0;
  static TextStyle? _titleStyle(ThemeData theme) => theme.textTheme.titleMedium;

  static TextStyle? _lineStyle(ThemeData theme, int i) =>
      theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: i == 0 ? FontWeight.w600 : null,
      );

  /// How tall [spec]'s card is at [width], with this screen's text size,
  /// language and fonts.
  static double heightFor(
    BuildContext context,
    _CardSpec spec, {
    required double width,
  }) {
    final theme = Theme.of(context);
    final base = DefaultTextStyle.of(context).style;
    final textWidth =
        width -
        _outer.horizontal -
        2 * (_border + _padding) -
        _leading -
        _gap -
        (spec.onTap == null ? 0 : _chevron);
    double measure(String text, TextStyle? style, double maxWidth) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: base.merge(style)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: max(1, maxWidth));
      final height = painter.height;
      painter.dispose();
      return height;
    }

    // A little narrower than the real line, so rounding never clips a wrap.
    var text = measure(spec.title, _titleStyle(theme), textWidth - 8);
    for (final (i, line) in spec.lines.indexed) {
      final lineWidth =
          i == 0 && spec.accent != null ? textWidth - _dot : textWidth;
      text += measure(line, _lineStyle(theme, i), lineWidth - 8);
    }
    // Room for rounding, so the text never overflows its card.
    return _outer.vertical + 2 * (_border + _padding) + max(_leading, text) + 8;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return MergeSemantics(
      child: Padding(
        padding: _outer,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: spec.selected ? c.primary : Colors.transparent,
              width: _border,
            ),
          ),
          child: Glass(
            radius: 24,
            onTap: spec.onTap,
            onLongPress: spec.onLongPress,
            padding: const EdgeInsets.all(_padding),
            child: Semantics(
              container: true,
              button: spec.onTap != null,
              onTap: spec.onTap,
              onLongPress: spec.onLongPress,
              excludeSemantics: true,
              label: [spec.title, ...spec.lines].join('\n'),
              child: Row(
                children: [
                  spec.leading,
                  const SizedBox(width: _gap),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(spec.title, style: _titleStyle(theme)),
                        for (final (i, line) in spec.lines.indexed)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (i == 0 && spec.accent != null) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: spec.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(line, style: _lineStyle(theme, i)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (spec.onTap != null)
                    Icon(Icons.chevron_right, color: c.outline),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
