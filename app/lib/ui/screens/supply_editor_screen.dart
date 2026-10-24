import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app/providers.dart';
import '../../core/haptics/haptics.dart';
import '../../gen/resilience/v1/event.pb.dart';
import '../../l10n/strings.dart';
import '../../location/location_providers.dart';
import '../../location/position_service.dart';
import '../../state/derived_state.dart';
import '../../supplies/supply_catalog.dart';
import '../../supplies/supply_service.dart';
import '../components/location_field.dart';
import '../components/toast.dart';

/// Create or edit a supply: what it is, how much (a number and a free-text
/// unit), when it is available, and where it is. Saving publishes signed
/// events; editing re-publishes under the same id (owner only).
///
/// When creating, the user can multi-select from the Round-2 item list (water,
/// food, medical, shelter, power, fuel, transport, hygiene, comms, tools, baby,
/// pets, other). Each selected item becomes its own signed supply (one event
/// per item), carrying the shared quantity/unit/notes/location and a free-text
/// title. Extra items (fuel/hygiene/comms/baby/pets) map onto existing proto
/// categories plus the item label (see supply_catalog.dart / DECISIONS.md).
class SupplyEditorScreen extends ConsumerStatefulWidget {
  /// Null => new supply.
  final ResourceView? editing;
  const SupplyEditorScreen({super.key, this.editing});

  @override
  ConsumerState<SupplyEditorScreen> createState() => _SupplyEditorState();
}

class _SupplyEditorState extends ConsumerState<SupplyEditorScreen> {
  final _title = TextEditingController();
  final _qty = TextEditingController();
  final _unit = TextEditingController();
  final _notes = TextEditingController();

  /// Selected item keys (multi-select) when creating. When editing we keep a
  /// single selection derived from the existing category.
  final Set<String> _items = <String>{};
  AmountBand _amount = AmountBand.AMOUNT_BAND_UNSPECIFIED;
  Availability _availability = Availability.AVAILABILITY_NOW;
  DateTime? _until;
  LatLng? _where;
  LocationSource _whereSource = LocationSource.LOCATION_SOURCE_UNSPECIFIED;
  bool _shelter = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      final r = e.resource;
      _title.text = r.title;
      _notes.text = r.notes;
      // Map the existing category back to a picker item (first match).
      for (final it in kSupplyItems) {
        if (it.category == r.category) {
          _items.add(it.key);
          break;
        }
      }
      _amount = r.amount;
      _availability = r.availability == Availability.AVAILABILITY_UNSPECIFIED
          ? Availability.AVAILABILITY_NOW
          : r.availability;
      if (r.availableUntilMs.toInt() > 0) {
        _until = DateTime.fromMillisecondsSinceEpoch(r.availableUntilMs.toInt());
      }
      _where = latLngOf(r.hasLocation() ? r.location : null);
      if (r.hasLocation() && r.location.hasLocationSource()) {
        _whereSource = r.location.locationSource;
      }
      _shelter = r.isShelter;
      if (e.inventory != null) {
        _qty.text = e.inventory!.quantity.toString();
        _unit.text = e.inventory!.unit;
      }
    } else {
      final me = ref.read(myPositionProvider);
      if (me != null) {
        _where = me;
        _whereSource = LocationSource.LOCATION_SOURCE_GPS;
      } else {
        final fix = ref.read(lastKnownFixProvider).valueOrNull;
        if (fix != null) {
          _where = fix.position;
          _whereSource = LocationSource.LOCATION_SOURCE_LAST_KNOWN;
        }
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _qty.dispose();
    _unit.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _until ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() {
      _until = DateTime(d.year, d.month, d.day, 23, 59);
      _availability = Availability.AVAILABILITY_CUSTOM;
    });
  }

  void _toggleItem(String key) {
    fireHaptic(ref, HapticKind.selection);
    setState(() {
      if (_isEditing) {
        // Editing stays a single item.
        _items
          ..clear()
          ..add(key);
      } else if (_items.contains(key)) {
        _items.remove(key);
      } else {
        _items.add(key);
      }
    });
  }

  Future<void> _save() async {
    final l = L10n.of(context);
    final title = _title.text.trim();
    int? qty;
    if (_qty.text.trim().isNotEmpty) {
      qty = int.tryParse(_qty.text.trim());
      if (qty == null || qty < 0) {
        setState(() => _error = l.t('qty_invalid'));
        return;
      }
    }
    if (_items.isEmpty) {
      setState(() => _error = l.t('supply_needs_category'));
      return;
    }
    // A free-text title is optional when at least one item is picked (the item
    // label stands in), but required if the user picked only "other".
    final onlyOther = _items.length == 1 && _items.first == 'other';
    if (onlyOther && title.isEmpty) {
      setState(() => _error = l.t('supply_needs_name'));
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final svc = await ref.read(supplyServiceProvider.future);
      final until = _availability == Availability.AVAILABILITY_TODAY
          ? DateTime(DateTime.now().year, DateTime.now().month,
              DateTime.now().day, 23, 59)
          : (_availability == Availability.AVAILABILITY_CUSTOM ? _until : null);
      final location =
          _where == null ? null : geoPointFor(_where!, source: _whereSource);

      // One signed supply event per selected item (the fold keys each by its
      // own resource id). The title defaults to the item label when the user
      // left the free-text field empty, so each supply is self-describing.
      for (final key in _items) {
        final item = supplyItemByKey(key)!;
        final itemLabel = title.isNotEmpty ? title : item.label(l);
        await svc.save(SupplyDraft(
          resourceId: _isEditing ? widget.editing!.resourceId : null,
          category: item.category,
          title: itemLabel,
          notes: _notes.text,
          quantity: qty,
          unit: _unit.text.trim(),
          amount: _amount,
          availability: _availability,
          availableUntil: until,
          location: location,
          isShelter: _shelter ||
              item.category == ResourceCategory.RESOURCE_CATEGORY_SHELTER,
        ));
      }
      bumpWorld(ref);
      if (!mounted) return;
      fireHaptic(ref, HapticKind.confirm);
      Toast.show(context, l.t('supply_saved'));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        fireHaptic(ref, HapticKind.error);
        setState(() {
          _saving = false;
          _error = l.t('supply_save_failed');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    const label = TextStyle(
        fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w600);
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? l.t('edit_supply') : l.t('add_supply'))),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text(l.t('supply_type'), style: label),
              const SizedBox(height: 4),
              if (!_isEditing)
                Text(l.t('supply_type_multi_hint'),
                    style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        color: scheme.outline)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final it in kSupplyItems)
                    FilterChip(
                      avatar: Icon(it.icon, size: 20),
                      label: Text(it.label(l)),
                      selected: _items.contains(it.key),
                      showCheckmark: false,
                      onSelected: (_) => _toggleItem(it.key),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontFamily: 'Roboto', fontSize: 16),
                decoration: InputDecoration(
                  labelText: l.t('item_name'),
                  hintText: l.t('item_name_hint'),
                ),
              ),
              const SizedBox(height: 16),
              Text(l.t('quantity'), style: label),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontFamily: 'Roboto', fontSize: 16),
                    decoration: InputDecoration(labelText: l.t('number')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _unit,
                    style: const TextStyle(fontFamily: 'Roboto', fontSize: 16),
                    decoration: InputDecoration(
                        labelText: l.t('unit'), hintText: l.t('unit_hint')),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(l.t('quantity_help'),
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      color: scheme.outline)),
              const SizedBox(height: 16),
              Text(l.t('amount'), style: label),
              const SizedBox(height: 8),
              Wrap(spacing: 10, children: [
                for (final a in const [
                  (AmountBand.AMOUNT_BAND_PLENTY, 'amount_plenty'),
                  (AmountBand.AMOUNT_BAND_SOME, 'amount_some'),
                  (AmountBand.AMOUNT_BAND_LOW, 'amount_low'),
                ])
                  ChoiceChip(
                    label: Text(l.t(a.$2)),
                    selected: _amount == a.$1,
                    onSelected: (v) => setState(() => _amount =
                        v ? a.$1 : AmountBand.AMOUNT_BAND_UNSPECIFIED),
                  ),
              ]),
              const SizedBox(height: 16),
              Text(l.t('availability'), style: label),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 8, children: [
                ChoiceChip(
                  label: Text(l.t('avail_now')),
                  selected: _availability == Availability.AVAILABILITY_NOW,
                  onSelected: (_) => setState(() {
                    _availability = Availability.AVAILABILITY_NOW;
                    _until = null;
                  }),
                ),
                ChoiceChip(
                  label: Text(l.t('avail_today')),
                  selected: _availability == Availability.AVAILABILITY_TODAY,
                  onSelected: (_) => setState(() {
                    _availability = Availability.AVAILABILITY_TODAY;
                    _until = null;
                  }),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.event_rounded, size: 20),
                  label: Text(_until == null
                      ? l.t('avail_until_date')
                      : '${l.t('avail_until')} ${MaterialLocalizations.of(context).formatMediumDate(_until!)}'),
                  selected: _availability == Availability.AVAILABILITY_CUSTOM,
                  onSelected: (_) => _pickDate(),
                ),
              ]),
              const SizedBox(height: 20),
              LocationField(
                  value: _where,
                  source: _whereSource,
                  onChanged: (v, s) => setState(() {
                        _where = v;
                        _whereSource = s;
                      })),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _shelter,
                onChanged: (v) => setState(() => _shelter = v),
                title: Text(l.t('is_shelter'),
                    style:
                        const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
              ),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 5,
                style: const TextStyle(fontFamily: 'Roboto', fontSize: 16),
                decoration: InputDecoration(
                    labelText: l.t('notes'), hintText: l.t('notes_hint')),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        color: scheme.error)),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(l.t('save_supply')),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
