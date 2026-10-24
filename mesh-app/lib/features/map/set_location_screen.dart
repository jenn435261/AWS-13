import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/demo_area.dart';
import '../../l10n/labels.dart';
import '../../models/help.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/surfaces.dart';
import '../../ui/theme.dart';
import 'map_pins.dart';
import 'street_map.dart';

/// Longest note for a location set by hand, like "Library, 2nd floor".
const maxLocationLabel = 80;

/// Opens the step where the person sets their location by hand, as its own
/// full-screen route, so Back returns to where they were. Starts at their
/// last location, or at [start] (usually what the map was showing).
Future<void> openSetLocation(BuildContext context, {LatLng? start}) {
  Haptics.tick();
  final fix = AppScope.of(context).repository.location.value;
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: SetLocationScreen.routeName),
      builder: (_) => SetLocationScreen(
        start: fix?.point ?? start ?? demoCenter,
        label: fix?.source == LocationSource.manual ? fix!.label : '',
      ),
    ),
  );
}

/// Rule 3, the manual fallback for when GPS can't help: drag the map under
/// a fixed pin to where you are, optionally say what is there, and confirm.
/// Nothing is looked up online; the point and the words stay as given.
class SetLocationScreen extends StatefulWidget {
  const SetLocationScreen({super.key, required this.start, this.label = ''});

  static const routeName = 'set-location';

  final LatLng start;
  final String label;

  @override
  State<SetLocationScreen> createState() => _SetLocationScreenState();
}

class _SetLocationScreenState extends State<SetLocationScreen> with StreetMapHost {
  final _map = MapController();
  late final _label = TextEditingController(text: widget.label);
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    await scope.repository.setManualLocation(_map.camera.center, label: _label.text.trim());
    scope.feedback.toast(l.mapLocationSaved, icon: Icons.where_to_vote_outlined);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l.mapSetLocation)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // While typing, the keyboard needs the room more than the hint.
          if (MediaQuery.viewInsetsOf(context).bottom == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(l.mapSetLocationTitle, style: theme.textTheme.headlineSmall),
                ),
                const SizedBox(height: 4),
                Text(l.mapSetLocationHint, style: TextStyle(color: c.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            child: Semantics(
              label: l.mapSetLocationHint,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: widget.start,
                      initialZoom: 17,
                      minZoom: 12,
                      maxZoom: 20,
                      backgroundColor: AppColors.of(context).map.base,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [StreetMapLayer(tiles: tiles)],
                  ),
                  // The pin stays put while the map moves under it; its tip
                  // marks the center of the map.
                  IgnorePointer(
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(0, -pinSize.height / 2),
                        child: SizedBox.fromSize(
                          size: pinSize,
                          child: MapPin(icon: Icons.person_pin_circle_outlined, hue: c.primary),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 8,
                    left: 12,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: StreetMapCredit(tiles: tiles),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _label,
                    maxLength: maxLocationLabel,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _confirm(),
                    decoration: InputDecoration(
                      labelText: l.mapLocationNote,
                      hintText: l.mapLocationNoteHint,
                      prefixIcon: const Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 8),
                  MainButton(
                    label: l.mapUseLocation,
                    icon: Icons.where_to_vote_outlined,
                    onPressed: _saving ? null : _confirm,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
