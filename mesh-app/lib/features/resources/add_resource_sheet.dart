import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/labels.dart';
import '../../models/resource.dart';
import '../../state/app_scope.dart';
import '../../state/drafts.dart';
import '../../ui/feedback.dart';
import '../../ui/step_scaffold.dart';
import '../../ui/visuals.dart';

/// Anyone can add a resource (Spec section 6). One tap picks the kind;
/// the note is optional. Others see it as an approximate location.
Future<void> showAddResourceSheet(BuildContext context, LatLng point) {
  Haptics.success();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: _AddResource(point: point, parent: context),
    ),
  );
}

class _AddResource extends StatefulWidget {
  const _AddResource({required this.point, required this.parent});

  final LatLng point;

  /// The map's context, which outlives this sheet for the undo toast.
  final BuildContext parent;

  @override
  State<_AddResource> createState() => _AddResourceState();
}

class _AddResourceState extends State<_AddResource> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _add(ResourceKind kind) {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final note = _note.text;
    Navigator.pop(context);
    String? id;
    scope.undoable(
      widget.parent,
      message: l.resourceAdded,
      undone: l.resourceRemoved,
      icon: Icons.add_location_alt_outlined,
      run: () async =>
          id = (await scope.repository.addResource(kind, widget.point, note: note)).id,
      revert: () => scope.repository.removeResource(id!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(l.addHereTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLength: maxNoteLength,
            decoration: InputDecoration(
              labelText: l.addNoteHint,
              prefixIcon: const Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 8),
          for (final kind in addableResourceKinds) ...[
            ChoiceTile(
              icon: resourceIcon(kind),
              hue: resourceHue(kind),
              title: l.resourceKind(kind),
              onTap: () {
                Haptics.tick();
                _add(kind);
              },
            ),
            const SizedBox(height: 8),
          ],
          Text(
            l.resourceAdded,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
