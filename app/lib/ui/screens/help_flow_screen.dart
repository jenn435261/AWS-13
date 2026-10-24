import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../gen/resilience/v1/event.pb.dart';
import '../../l10n/strings.dart';
import '../../location/position_service.dart';
import '../components/common.dart';
import '../components/location_field.dart';
import '../components/toast.dart';
import '../components/trust_badges.dart';

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
  final Set<ResourceCategory> _selected = {};
  final TextEditingController _note = TextEditingController();
  AmountBand _amount = AmountBand.AMOUNT_BAND_UNSPECIFIED;
  Availability _availability = Availability.AVAILABILITY_NOW;
  bool _aiBusy = false;
  LatLng? _where;
  bool _sending = false;

  static const _categories = <ResourceCategory>[
    ResourceCategory.RESOURCE_CATEGORY_WATER,
    ResourceCategory.RESOURCE_CATEGORY_FOOD,
    ResourceCategory.RESOURCE_CATEGORY_MEDICINE,
    ResourceCategory.RESOURCE_CATEGORY_SHELTER,
    ResourceCategory.RESOURCE_CATEGORY_POWER,
    ResourceCategory.RESOURCE_CATEGORY_TRANSPORTATION,
    ResourceCategory.RESOURCE_CATEGORY_MEDICAL_HELP,
    ResourceCategory.RESOURCE_CATEGORY_COMMUNICATION,
    ResourceCategory.RESOURCE_CATEGORY_OTHER,
  ];

  @override
  void initState() {
    super.initState();
    _where = ref.read(myPositionProvider);
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
    // Map the suggested category name back to the enum and pre-select it.
    final match = _categories.firstWhere(
      (c) => c.name.replaceFirst('RESOURCE_CATEGORY_', '') == result.category,
      orElse: () => ResourceCategory.RESOURCE_CATEGORY_OTHER,
    );
    setState(() {
      _selected.add(match);
      _aiBusy = false;
    });
    Toast.show(
      context,
      result.degraded
          ? '${L10n.of(context).t('ai_offline_suggestion')}: ${result.shortTitle}'
          : result.shortTitle,
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
        final body = HelpRequestBody(
          requestId: const Uuid().v4(),
          categories: _selected,
          freeform: _note.text.trim(),
          priority: _selected
                  .contains(ResourceCategory.RESOURCE_CATEGORY_MEDICAL_HELP)
              ? Priority.PRIORITY_HIGH
              : Priority.PRIORITY_NORMAL,
          location: _where == null ? null : geoPointFor(_where!),
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
          categories: _selected,
          amount: _amount,
          availability: _availability,
          notes: _note.text.trim(),
          location: _where == null ? null : geoPointFor(_where!),
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
      HapticFeedback.mediumImpact();
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
                    children: _categories.map((c) {
                      final selected = _selected.contains(c);
                      return FilterChip(
                        avatar: Icon(iconForCategory(c),
                            size: 22,
                            color: selected
                                ? Theme.of(context).colorScheme.onPrimary
                                : null),
                        label: Text(categoryLabel(l, c)),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (v) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (v) {
                              _selected.add(c);
                            } else {
                              _selected.remove(c);
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
                      onChanged: (v) => setState(() => _where = v)),
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
                onPressed: canSend ? _send : null,
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
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}
