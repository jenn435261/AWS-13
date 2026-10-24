import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../../location/position_service.dart';
import '../map/map_view.dart';
import 'toast.dart';

/// "Where is this?" for requests and supplies: use the device position (asked
/// only when tapped), pick a point on the map, or leave it unset. The value is
/// rounded to ~110 m before it is published (see [geoPointFor]).
class LocationField extends ConsumerStatefulWidget {
  final LatLng? value;
  final ValueChanged<LatLng?> onChanged;
  const LocationField({super.key, required this.value, required this.onChanged});

  @override
  ConsumerState<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends ConsumerState<LocationField> {
  bool _busy = false;

  Future<void> _useMine() async {
    final l = L10n.of(context);
    setState(() => _busy = true);
    final r = await readPosition();
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.position != null) {
      ref.read(myPositionProvider.notifier).state = r.position;
      widget.onChanged(r.position);
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

  Future<void> _pick() async {
    final p = await Navigator.of(context).push<LatLng>(MaterialPageRoute(
        builder: (_) => MapPickerScreen(initial: widget.value)));
    if (p != null) widget.onChanged(p);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final v = widget.value;
    final outline = Theme.of(context).colorScheme.outline;
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
              : '${roundCoord(v.latitude).toStringAsFixed(3)}, ${roundCoord(v.longitude).toStringAsFixed(3)} · ${l.t('location_approx')}',
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
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.edit_location_alt_outlined),
            label: Text(l.t('pick_on_map')),
          ),
          if (v != null)
            TextButton(
                onPressed: () => widget.onChanged(null),
                child: Text(l.t('clear'))),
        ]),
      ],
    );
  }
}

/// Full-screen map: tap to drop a pin, then confirm.
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
    return Scaffold(
      appBar: AppBar(title: Text(l.t('pick_on_map'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(l.t('pick_hint'),
              style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
        ),
        Expanded(
          child: MapView(
            me: me,
            center: widget.initial ?? me,
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
