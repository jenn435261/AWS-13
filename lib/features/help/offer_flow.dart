import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../models/help.dart';
import '../../state/app_scope.dart';
import '../../state/drafts.dart';
import '../../ui/feedback.dart';
import '../../ui/step_scaffold.dart';
import '../../ui/visuals.dart';

/// Offering supplies (Spec sections 5 and 21): two taps plus optional
/// detail, never a long inventory form.

void openOfferFlow(BuildContext context) {
  final router = GoRouter.of(context);
  final scope = AppScope.of(context);
  // Editing an existing offer starts from what it already says.
  scope.offerDraft
    ..loadFrom(scope.repository.offer.value)
    ..returnTo = router.routerDelegate.currentConfiguration.uri.toString();
  router.push('/offer');
}

void _close(BuildContext context) =>
    GoRouter.of(context).go(AppScope.of(context).offerDraft.returnTo);

class OfferKindsStep extends StatelessWidget {
  const OfferKindsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final draft = AppScope.of(context).offerDraft;

    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => StepScaffold(
        step: 1,
        total: 2,
        title: l.offerStep1Title,
        actionLabel: l.next,
        onAction: draft.kinds.isEmpty ? null : () => context.push('/offer/details'),
        onClose: () => _close(context),
        children: [
          for (final kind in SupplyKind.values) ...[
            ChoiceTile(
              icon: supplyIcon(kind),
              title: l.supply(kind),
              multiSelect: true,
              selected: draft.kinds.contains(kind),
              onTap: () {
                Haptics.tick();
                draft.toggle(kind);
              },
            ),
            const SizedBox(height: 10),
          ],
          if (draft.kinds.isEmpty) Text(l.problemSupplies),
        ],
      ),
    );
  }
}

class OfferDetailsStep extends StatefulWidget {
  const OfferDetailsStep({super.key});

  @override
  State<OfferDetailsStep> createState() => _OfferDetailsStepState();
}

class _OfferDetailsStepState extends State<OfferDetailsStep> {
  late final OfferDraft _draft = AppScope.of(context).offerDraft;
  late final _note = TextEditingController(text: _draft.note);
  late final _when = TextEditingController(text: _draft.availabilityNote);

  @override
  void dispose() {
    _note.dispose();
    _when.dispose();
    super.dispose();
  }

  void _start() {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final previous = scope.repository.offer.value;
    final offer = _draft.build();

    GoRouter.of(context).go(_draft.offersTransport ? '/more/deliveries' : '/map');
    scope.undoable(
      context,
      message: l.offeringStarted,
      undone: l.offerStopped,
      icon: Icons.volunteer_activism,
      run: () => scope.repository.setOffer(offer),
      revert: () => scope.repository.setOffer(previous),
    );
  }

  /// A row of large pick-one buttons. Uses the platform's segmented button.
  Widget _pick<T>(List<(T, String, IconData?)> options, T selected, void Function(T) onPick) =>
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<T>(
          showSelectedIcon: false,
          segments: [
            for (final (value, label, icon) in options)
              ButtonSegment(
                value: value,
                label: Text(label, textAlign: TextAlign.center),
                icon: icon == null ? null : Icon(icon),
              ),
          ],
          selected: {selected},
          onSelectionChanged: (s) {
            Haptics.tick();
            _draft.update(() => onPick(s.first));
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    Widget question(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 10),
          child: Text(text, style: theme.textTheme.titleMedium),
        );

    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) {
        final problems = _draft.problems;
        return StepScaffold(
          step: 2,
          total: 2,
          title: l.offerStep2Title,
          actionLabel: l.startOffering,
          actionIcon: Icons.volunteer_activism,
          onAction: problems.isEmpty ? _start : null,
          onClose: () => _close(context),
          children: [
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.volunteer_activism, size: 28),
                title: Text(l.supplies(_draft.kinds)),
                trailing: TextButton(onPressed: () => context.pop(), child: Text(l.edit)),
              ),
            ),
            question(l.amountQuestion),
            _pick(
              [for (final a in Amount.values) (a, l.amount(a), null)],
              _draft.amount,
              (a) => _draft.amount = a,
            ),
            question(l.availabilityQuestion),
            _pick(
              [for (final a in Availability.values) (a, l.availability(a), null)],
              _draft.availability,
              (a) => _draft.availability = a,
            ),
            if (_draft.availability == Availability.custom) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _when,
                onChanged: (v) => _draft.availabilityNote = v,
                decoration: InputDecoration(
                  labelText: l.availabilityNoteLabel,
                  hintText: l.availabilityNoteHint,
                  prefixIcon: const Icon(Icons.schedule),
                ),
              ),
            ],
            if (_draft.offersTransport) ...[
              question(l.transportQuestion),
              for (final t in TransportMode.values) ...[
                ChoiceTile(
                  icon: transportIcon(t),
                  title: l.transport(t),
                  selected: _draft.transport == t,
                  onTap: () {
                    Haptics.tick();
                    _draft.update(() => _draft.transport = t);
                  },
                ),
                const SizedBox(height: 8),
              ],
              question(l.capacityQuestion),
              _pick(
                [for (final cap in Capacity.values) (cap, l.capacity(cap), null)],
                _draft.capacity,
                (cap) => _draft.capacity = cap,
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLength: maxNoteLength,
              minLines: 2,
              maxLines: 4,
              onChanged: (v) => _draft.note = v,
              decoration: InputDecoration(
                labelText: l.offerNoteLabel,
                hintText: l.offerNoteHint,
                prefixIcon: const Icon(Icons.notes),
              ),
            ),
            for (final p in problems)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.error_outline, color: c.error),
                title: Text(l.problem(p), style: TextStyle(color: c.error)),
              ),
          ],
        );
      },
    );
  }
}
