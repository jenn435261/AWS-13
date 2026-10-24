import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../core/haptics/haptics.dart';
import '../../gen/resilience/v1/event.pb.dart';
import '../../l10n/strings.dart';
import '../../location/location_providers.dart';
import '../../location/position_service.dart';
import '../../supplies/supply_catalog.dart';
import '../components/common.dart';
import '../components/location_field.dart';
import '../components/toast.dart';

/// The core emergency action: "I NEED HELP" (request) or "OFFER HELP" (offer).
///
/// Designed for the fewest possible steps (a requester may be injured):
///   1) tap one or more category pills
///   2) optionally add a note (or let AI structure it)
///   3) tap Send
/// Everything else (amount/availability) is behind an Advanced disclosure so
/// the primary path stays two taps + send. Haptics on send; undo toast.
class HelpFlowScreen extends ConsumerStatefulWidget {
  final bool isRequest;
  const HelpFlowScreen({super.key, required this.isRequest});

  @override
  ConsumerState<HelpFlowScreen> createState() => _HelpFlowScreenState();
}

class _HelpFlowScreenState extends ConsumerState<HelpFlowScreen> {
  /// Selected picker item keys (multi-select). Mapped to proto categories on
  /// send (several items can map to the same category — deduped there).
  final Set<String> _selected = {};
  final TextEditingController _note = TextEditingController();
  AmountBand _amount = AmountBand.AMOUNT_BAND_UNSPECIFIED;
  Availability _availability = Availability.AVAILABILITY_NOW;
  bool _aiBusy = false;
  LatLng? _where;
  LocationSource _whereSource = LocationSource.LOCATION_SOURCE_UNSPECIFIED;
  bool _sending = false;

  /// The set of proto categories implied by the selected picker items.
  Set<ResourceCategory> get _selectedCategories =>
      _selected.map((k) => supplyItemByKey(k)!.category).toSet();

  @override
  void initState() {
    super.initState();
    // Default the new-post location to the freshest thing we have, labelled
    // honestly: a live fix (GPS) if one is loaded, otherwise the cached
    // last-known fix (LAST_KNOWN). The user can override via LocationField.
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

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _structureWithAi() async {
    final text = _note.text.trim();
    if (text.isEmpty) return;
    setState(() => _aiBusy = true);
    final ai = ref.read(aiAssistProvider);
    final result = await ai.structure(text);
    if (!mounted) return;
    // Map the suggested category name back to a picker item and pre-select it.
    final match = kSupplyItems.firstWhere(
      (it) =>
          it.category.name.replaceFirst('RESOURCE_CATEGORY_', '') ==
          result.category,
      orElse: () => kSupplyItems.last, // "other"
    );
    setState(() {
      _selected.add(match.key);
      _aiBusy = false;
    });
    Toast.show(
      context,
      result.degraded
          ? '${L10n.of(context).t('ai_offline_suggestion')}: ${result.shortTitle}'
          : result.shortTitle,
    );
  }

  /// Entry point for the primary action. For a help REQUEST we first run a
  /// non-blocking near-duplicate check (AI dedup, with the deterministic rules
  /// fallback) against the currently open requests; if a very similar one
  /// already exists we offer to view it or submit anyway. Offers skip this.
  Future<void> _onSendPressed() async {
    if (!widget.isRequest) {
      await _send();
      return;
    }
    final candidate = _candidateText();
    if (candidate.trim().isEmpty) {
      await _send();
      return;
    }
    final world = ref.read(worldStateProvider).valueOrNull;
    final existing = <String>[];
    if (world != null) {
      for (final q in world.helpRequests) {
        if (q.closed) continue;
        final text = q.body.freeform.trim();
        if (text.isNotEmpty) existing.add(text);
      }
    }
    if (existing.isEmpty) {
      await _send();
      return;
    }
    setState(() => _sending = true);
    final hits = await ref.read(aiAssistProvider).dedup(candidate, existing);
    if (!mounted) return;
    setState(() => _sending = false);
    if (hits.isEmpty) {
      await _send();
      return;
    }
    await _showDedupWarning(hits.first.text);
  }

  /// The text used for the near-duplicate check: the note, falling back to the
  /// selected category labels so a note-less request still de-dupes sensibly.
  String _candidateText() {
    final note = _note.text.trim();
    if (note.isNotEmpty) return note;
    final l = L10n.of(context);
    return _selected.map((k) => supplyItemByKey(k)!.label(l)).join(', ');
  }

  Future<void> _showDedupWarning(String existingText) async {
    final l = L10n.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.t('dedup_warning_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.t('dedup_warning_body'),
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(dialogCtx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(existingText, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        actions: [
          // "View existing" is non-destructive: close the dialog and the flow
          // so the user lands back on the map where the existing request shows.
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              Navigator.of(context).pop();
            },
            child: Text(l.t('view_existing'),
                style: const TextStyle(fontSize: 16)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _send();
            },
            child: Text(l.t('submit_anyway'),
                style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final l = L10n.of(context);
    setState(() => _sending = true);
    try {
      final id = await ref.read(identityProvider.future);
      final kp = await authorKeyPair(id);
      final store = ref.read(eventStoreProvider);
      final factory = ref.read(eventFactoryProvider);
      final clock = store.clock;

      final SignedEvent event;
      if (widget.isRequest) {
        final cats = _selectedCategories;
        final body = HelpRequestBody(
          requestId: const Uuid().v4(),
          categories: cats,
          freeform: _note.text.trim(),
          priority: cats.contains(
                      ResourceCategory.RESOURCE_CATEGORY_MEDICAL_HELP) ||
                  cats.contains(ResourceCategory.RESOURCE_CATEGORY_MEDICINE)
              ? Priority.PRIORITY_HIGH
              : Priority.PRIORITY_NORMAL,
          location: _where == null
              ? null
              : geoPointFor(_where!, source: _whereSource),
        );
        event = await factory.buildFromMessage(
          keyPair: kp,
          clock: clock,
          type: EventType.EVENT_TYPE_HELP_REQUESTED,
          body: body,
        );
      } else {
        final body = HelpOfferBody(
          offerId: const Uuid().v4(),
          categories: _selectedCategories,
          amount: _amount,
          availability: _availability,
          notes: _note.text.trim(),
          location: _where == null
              ? null
              : geoPointFor(_where!, source: _whereSource),
        );
        event = await factory.buildFromMessage(
          keyPair: kp,
          clock: clock,
          type: EventType.EVENT_TYPE_HELP_OFFERED,
          body: body,
        );
      }

      final result = await store.apply(event);
      bumpWorld(ref);
      if (!mounted) return;
      // A sent help request is the SOS-grade success pattern; an offer is a
      // standard confirm.
      fireHaptic(
          ref, widget.isRequest ? HapticKind.success : HapticKind.confirm);
      Toast.show(
        context,
        widget.isRequest ? l.t('request_sent') : l.t('offer_sent'),
        undoLabel: l.t('undo'),
        onUndo: () {
          // Undo = append a withdrawal note (events are immutable; we model
          // undo as a user-facing retraction toast for the demo).
          Toast.show(context, l.t('undo'));
        },
      );
      Navigator.of(context).pop(result);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final title = widget.isRequest ? l.t('i_need_help') : l.t('offer_help');
    final canSend = _selected.isNotEmpty && !_sending;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.isRequest
                        ? l.t('what_do_you_need')
                        : l.t('offer_help'),
                    style: const TextStyle(fontFamily: 'Roboto', 
                        fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: kSupplyItems.map((it) {
                      final selected = _selected.contains(it.key);
                      return FilterChip(
                        avatar: Icon(it.icon,
                            size: 22,
                            color: selected
                                ? Theme.of(context).colorScheme.onPrimary
                                : null),
                        label: Text(it.label(l)),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (v) {
                          fireHaptic(ref, HapticKind.selection);
                          setState(() {
                            if (v) {
                              _selected.add(it.key);
                            } else {
                              _selected.remove(it.key);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(l.t('anything_else'),
                      style: const TextStyle(fontFamily: 'Roboto', 
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _note,
                    minLines: 2,
                    maxLines: 4,
                    style: const TextStyle(fontFamily: 'Roboto', fontSize: 16),
                    decoration: InputDecoration(
                      hintText: l.t('add_a_note'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _aiBusy ? null : _structureWithAi,
                    icon: _aiBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(l.t('structure_with_ai')),
                  ),
                  const SizedBox(height: 20),
                  LocationField(
                      value: _where,
                      source: _whereSource,
                      onChanged: (v, s) => setState(() {
                            _where = v;
                            _whereSource = s;
                          })),
                  if (!widget.isRequest) ...[
                    const SizedBox(height: 8),
                    AdvancedDisclosure(
                      label: l.t('advanced_options'),
                      children: [
                        const SizedBox(height: 8),
                        Text(l.t('amount'),
                            style: const TextStyle(fontFamily: 'Roboto', 
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 10, children: [
                          _choice(l.t('amount_plenty'),
                              _amount == AmountBand.AMOUNT_BAND_PLENTY, () {
                            setState(
                                () => _amount = AmountBand.AMOUNT_BAND_PLENTY);
                          }),
                          _choice(l.t('amount_some'),
                              _amount == AmountBand.AMOUNT_BAND_SOME, () {
                            setState(
                                () => _amount = AmountBand.AMOUNT_BAND_SOME);
                          }),
                          _choice(l.t('amount_low'),
                              _amount == AmountBand.AMOUNT_BAND_LOW, () {
                            setState(
                                () => _amount = AmountBand.AMOUNT_BAND_LOW);
                          }),
                        ]),
                        const SizedBox(height: 16),
                        Text(l.t('availability'),
                            style: const TextStyle(fontFamily: 'Roboto', 
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 10, children: [
                          _choice(l.t('avail_now'),
                              _availability == Availability.AVAILABILITY_NOW,
                              () {
                            setState(() =>
                                _availability = Availability.AVAILABILITY_NOW);
                          }),
                          _choice(l.t('avail_today'),
                              _availability == Availability.AVAILABILITY_TODAY,
                              () {
                            setState(() => _availability =
                                Availability.AVAILABILITY_TODAY);
                          }),
                        ]),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Primary action pinned at the bottom (hard UI rule).
            Padding(
              padding: const EdgeInsets.all(16),
              child: PrimaryActionButton(
                label: widget.isRequest
                    ? l.t('send_request')
                    : l.t('send_offer'),
                icon: Icons.send_rounded,
                urgent: widget.isRequest,
                onPressed: canSend ? _onSendPressed : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        fireHaptic(ref, HapticKind.selection);
        onTap();
      },
    );
  }
}
