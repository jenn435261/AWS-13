import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app/providers.dart';
import '../../gen/resilience/v1/event.pb.dart';
import '../../l10n/strings.dart';
import '../../location/dead_reckoning/dead_reckoning.dart';
import '../../location/dead_reckoning/estimate.dart';
import '../../location/location_providers.dart';
import '../../location/position_service.dart';
import '../map/map_view.dart';
import 'toast.dart';

/// "Where is this?" for requests and supplies. The user can:
///  * use the device position (asked only when tapped) — source GPS;
///  * use the cached last-known fix — source LAST_KNOWN, labelled with its age;
///  * drop a pin on the map, type coordinates, or search a place in a
///    downloaded region — source MANUAL;
///  * leave it unset.
///
/// The value is rounded to ~110 m before it is published (see [geoPointFor]),
/// and the [LocationSource] is carried onto the event so the map and read
/// models can show how a point was obtained — honestly, never implying GPS.
class LocationField extends ConsumerStatefulWidget {
  final LatLng? value;
  final LocationSource source;
  final void Function(LatLng? value, LocationSource source) onChanged;
  const LocationField({
    super.key,
    required this.value,
    required this.onChanged,
    this.source = LocationSource.LOCATION_SOURCE_UNSPECIFIED,
  });

  @override
  ConsumerState<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends ConsumerState<LocationField> {
  bool _busy = false;

  Future<void> _useMine() async {
    final l = L10n.of(context);
    setState(() => _busy = true);
    final r = await autoResolvePosition(ref);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.position != null) {
      widget.onChanged(r.position, LocationSource.LOCATION_SOURCE_GPS);
      return;
    }
    Toast.show(
        context,
        switch (r.failure) {
          PositionFailure.serviceOff => l.t('loc_service_off'),
          PositionFailure.denied ||
          PositionFailure.deniedForever =>
            l.t('loc_denied'),
          PositionFailure.timeout => l.t('loc_timeout'),
          _ => l.t('loc_unknown'),
        },
        urgent: true);
  }

  Future<void> _useLastKnown() async {
    final fix = await ref.read(lastKnownFixProvider.future);
    if (fix == null || !mounted) return;
    widget.onChanged(
        fix.position, LocationSource.LOCATION_SOURCE_LAST_KNOWN);
  }

  Future<void> _pick() async {
    final p = await Navigator.of(context).push<LatLng>(MaterialPageRoute(
        builder: (_) => MapPickerScreen(initial: widget.value)));
    if (p != null) widget.onChanged(p, LocationSource.LOCATION_SOURCE_MANUAL);
  }

  Future<void> _typeCoords() async {
    final p = await showDialog<LatLng>(
      context: context,
      builder: (_) => _CoordinateDialog(initial: widget.value),
    );
    if (p != null) widget.onChanged(p, LocationSource.LOCATION_SOURCE_MANUAL);
  }

  /// Estimated position (dead-reckoning). Native only: coasts from the cached
  /// last-known fix with a growing uncertainty radius. On web it is honestly
  /// unavailable (no motion sensors in a browser).
  Future<void> _estimate() async {
    final l = L10n.of(context);
    if (!deadReckoningAvailable()) {
      Toast.show(context, l.t('estimated_unavailable_web'));
      return;
    }
    final fix = await ref.read(lastKnownFixProvider.future);
    if (fix == null || !mounted) return;
    final reckoner = DeadReckoner();
    final DeadReckonEstimate? est = reckoner.estimate(fix);
    reckoner.dispose();
    if (est == null || !mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => _EstimateDialog(estimate: est),
    );
    if (accepted == true) {
      widget.onChanged(est.point, LocationSource.LOCATION_SOURCE_ESTIMATED);
    }
  }

  String _sourceLabel(L10n l) {
    switch (widget.source) {
      case LocationSource.LOCATION_SOURCE_GPS:
        return l.t('loc_source_gps');
      case LocationSource.LOCATION_SOURCE_MANUAL:
        return l.t('loc_source_manual');
      case LocationSource.LOCATION_SOURCE_LAST_KNOWN:
        return l.t('loc_source_last_known');
      case LocationSource.LOCATION_SOURCE_ESTIMATED:
        return l.t('loc_source_estimated');
      default:
        return l.t('location_approx');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final v = widget.value;
    final outline = Theme.of(context).colorScheme.outline;
    final lastFix = ref.watch(lastKnownFixProvider).valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.t('location'),
            style: const TextStyle(
                fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          v == null
              ? l.t('location_none')
              : '${roundCoord(v.latitude).toStringAsFixed(3)}, ${roundCoord(v.longitude).toStringAsFixed(3)} · ${_sourceLabel(l)}',
          style: TextStyle(fontFamily: 'Roboto', fontSize: 16, color: outline),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _useMine,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location_rounded),
            label: Text(l.t('use_my_location')),
          ),
          if (lastFix != null)
            OutlinedButton.icon(
              onPressed: _useLastKnown,
              icon: const Icon(Icons.history_rounded),
              label: Text(
                  '${l.t('loc_last_known')}, ${lastFix.ageLabel(DateTime.now().toUtc().millisecondsSinceEpoch)}'),
            ),
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.edit_location_alt_outlined),
            label: Text(l.t('set_location_manually')),
          ),
          OutlinedButton.icon(
            onPressed: _typeCoords,
            icon: const Icon(Icons.pin_drop_outlined),
            label: Text(l.t('enter_coordinates')),
          ),
          if (deadReckoningAvailable() && lastFix != null)
            OutlinedButton.icon(
              onPressed: _estimate,
              icon: const Icon(Icons.explore_outlined),
              label: Text(l.t('estimated_position')),
            ),
          if (v != null)
            TextButton(
                onPressed: () => widget.onChanged(
                    null, LocationSource.LOCATION_SOURCE_UNSPECIFIED),
                child: Text(l.t('clear'))),
        ]),
      ],
    );
  }
}

/// Type latitude/longitude by hand (a manual pin without the map). Validates
/// the ranges so an out-of-range value never becomes a point.
class _CoordinateDialog extends StatefulWidget {
  final LatLng? initial;
  const _CoordinateDialog({this.initial});
  @override
  State<_CoordinateDialog> createState() => _CoordinateDialogState();
}

class _CoordinateDialogState extends State<_CoordinateDialog> {
  late final TextEditingController _lat;
  late final TextEditingController _lon;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lat = TextEditingController(
        text: widget.initial == null ? '' : '${widget.initial!.latitude}');
    _lon = TextEditingController(
        text: widget.initial == null ? '' : '${widget.initial!.longitude}');
  }

  @override
  void dispose() {
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  void _submit() {
    final lat = double.tryParse(_lat.text.trim());
    final lon = double.tryParse(_lon.text.trim());
    if (lat == null ||
        lon == null ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      setState(() => _error = L10n.of(context).t('coord_invalid'));
      return;
    }
    Navigator.of(context).pop(LatLng(lat, lon));
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return AlertDialog(
      title: Text(l.t('enter_coordinates')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _lat,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))
            ],
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(labelText: l.t('coord_lat')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _lon,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))
            ],
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(labelText: l.t('coord_lon')),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: TextStyle(
                    fontSize: 16, color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.t('cancel'), style: const TextStyle(fontSize: 16))),
        FilledButton(
            onPressed: _submit,
            child:
                Text(l.t('use_this_point'), style: const TextStyle(fontSize: 16))),
      ],
    );
  }
}

/// Shows the dead-reckoned estimate with its honest uncertainty radius and asks
/// the user to accept it as their position. Accepting stamps an event with
/// location_source = ESTIMATED (never GPS).
class _EstimateDialog extends StatelessWidget {
  final DeadReckonEstimate estimate;
  const _EstimateDialog({required this.estimate});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final radius = estimate.radiusM;
    return AlertDialog(
      title: Text(l.t('estimated_position')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('estimated_hint'), style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 10),
          Text(
            '± ${radius >= 1000 ? '${(radius / 1000).toStringAsFixed(1)} km' : '${radius.round()} m'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.t('cancel'), style: const TextStyle(fontSize: 16))),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.t('estimated_accept'),
                style: const TextStyle(fontSize: 16))),
      ],
    );
  }
}

/// Full-screen map: tap to drop a pin, then confirm. A dropped pin is a MANUAL
/// location.
class MapPickerScreen extends ConsumerStatefulWidget {
  final LatLng? initial;
  const MapPickerScreen({super.key, this.initial});
  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerState();
}

class _MapPickerState extends ConsumerState<MapPickerScreen> {
  LatLng? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final me = ref.watch(myPositionProvider);
    final lastFix = ref.watch(lastKnownFixProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l.t('set_location_manually'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(l.t('pick_hint'),
              style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
        ),
        Expanded(
          child: MapView(
            me: me,
            center: widget.initial ?? me ?? lastFix?.position,
            picked: _picked,
            onPick: (p) => setState(() => _picked = p),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    _picked == null ? null : () => Navigator.pop(context, _picked),
                child: Text(l.t('use_this_point')),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
