import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/labels.dart';
import '../../models/resource.dart';
import '../../state/app_scope.dart';
import '../../ui/empty_state.dart';
import '../../ui/feedback.dart';
import '../../ui/info_chip.dart';
import '../../ui/resource_badge.dart';
import '../../ui/visuals.dart';
import '../../utils/format.dart';

// ResourceBadge and resourceMark moved to lib/ui; screens that imported them
// from here keep working.
export '../../ui/resource_badge.dart' show ResourceBadge, resourceMark;

/// A resource with its three kinds of trust shown separately: who says so,
/// how many people agree, and how fresh it is (Spec sections 7 to 10).
Future<void> showResourceSheet(BuildContext context, String id) {
  Haptics.tick();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (sheet, controller) => _ResourceDetails(id: id, scroll: controller),
    ),
  );
}

class _ResourceDetails extends StatelessWidget {
  const _ResourceDetails({required this.id, required this.scroll});

  final String id;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return ValueListenableBuilder<List<Resource>>(
      valueListenable: scope.repository.resources,
      builder: (context, resources, _) {
        final r = resources.where((r) => r.id == id).firstOrNull;
        if (r == null) {
          return EmptyState(icon: Icons.wrong_location_outlined, message: l.resourceNotFound);
        }
        final stale = r.isStale();
        final here = scope.repository.location.value?.point;

        Widget trustRow(IconData icon, String label, List<String> lines,
                {Color? color}) =>
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, color: color),
              title: Text(label, style: theme.textTheme.titleMedium),
              subtitle: Text(lines.join('\n')),
            );

        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Row(
              children: [
                ResourceBadge(resource: r, size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.resourceTitle(r), style: theme.textTheme.titleLarge),
                      Text(
                        [
                          l.resourceKind(r.kind),
                          if (here != null) l.distance(metersBetween(here, r.location)),
                        ].join('  ·  '),
                        style: TextStyle(color: c.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoChip(
                  icon: provenanceIcon(r),
                  label: r.verified
                      ? l.verifiedOrg
                      : r.confidence == Confidence.unconfirmed
                          ? l.unconfirmed
                          : l.communityResource,
                  strong: r.verified,
                ),
                InfoChip(icon: Icons.insights_outlined, label: l.confidence(r.confidence)),
                if (r.mine) InfoChip(icon: Icons.person_outline, label: l.addedByYou),
              ],
            ),
            const SizedBox(height: 8),
            trustRow(
              r.verified ? Icons.verified : Icons.groups_outlined,
              l.trustSource,
              [r.verified ? '${l.verifiedOrg}: ${r.organization}' : l.communityResource],
              color: r.verified ? c.primary : null,
            ),
            trustRow(
              Icons.fact_check_outlined,
              l.trustCorroboration,
              [
                r.confirmations == 0 && !r.verified
                    ? l.oneReport
                    : '${l.confirmationsCount(r.confirmations)}, '
                        '${l.disputesCount(r.disputes)}',
              ],
            ),
            trustRow(
              stale ? Icons.history_toggle_off : Icons.update,
              l.trustFreshness,
              [
                if (r.officialUpdate != null) l.officialUpdate(l.timeAgo(r.officialUpdate!)),
                stale
                    ? l.staleWarning(l.timeAgo(r.lastObserved))
                    : l.lastObservation(l.timeAgo(r.lastObserved)),
              ],
              color: stale ? c.error : null,
            ),
            if (r.officialStock != null || r.observations.isNotEmpty)
              trustRow(
                Icons.inventory_2_outlined,
                l.inventoryTitle,
                [
                  if (r.officialStock != null && r.officialUpdate != null)
                    l.officialStock(r.officialStock!, clockTime(r.officialUpdate!)),
                  if (r.reserved != null && r.reservedFor != null)
                    l.reservedFor(r.reserved!, r.reservedFor!),
                  if (r.remaining != null) l.remainingCount(r.remaining!),
                  if (r.observations.isNotEmpty) ...[
                    '${l.communityReports}:',
                    for (final o in r.observations)
                      l.observationAt(o.text, clockTime(o.at)),
                  ],
                ],
              ),
            if (r.note.isNotEmpty)
              trustRow(Icons.notes, l.detailsTitle, [r.note]),
            if (r.approximate)
              trustRow(Icons.blur_circular, l.approxLocation, [l.distance(_approx(here, r.location))]),
            const SizedBox(height: 12),
            _VoteButtons(resource: r),
          ],
        );
      },
    );
  }

  static double _approx(LatLng? here, LatLng point) =>
      here == null ? 0 : metersBetween(here, point);
}

class _VoteButtons extends StatelessWidget {
  const _VoteButtons({required this.resource});

  final Resource resource;

  Future<void> _vote(BuildContext context, Vote vote) {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final next = resource.myVote == vote ? null : vote;
    return scope.undoable(
      context,
      message: next == null ? l.voteWithdrawnToast : l.voted,
      undone: next == null ? l.voted : l.voteWithdrawnToast,
      icon: next == null ? Icons.undo : Icons.how_to_vote_outlined,
      run: () => scope.repository.vote(resource.id, next),
      revert: () => scope.repository.restoreVote(resource),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final options = [
      (Vote.confirm, Icons.check_circle_outline, l.voteConfirm, l.voteConfirmSub),
      (Vote.dispute, Icons.report_outlined, l.voteDispute, l.voteDisputeSub),
      (Vote.useful, Icons.thumb_up_outlined, l.voteUseful, null),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (vote, icon, label, sub) in options) ...[
          _VoteButton(
            icon: icon,
            label: label,
            subtitle: sub,
            selected: resource.myVote == vote,
            onTap: () => _vote(context, vote),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final child = Row(
      children: [
        Icon(selected ? Icons.check_circle : icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: selected ? c.onPrimary : c.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    final style = ButtonStyle(
      alignment: Alignment.centerLeft,
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
    return Semantics(
      selected: selected,
      child: selected
          ? FilledButton(style: style, onPressed: onTap, child: child)
          : OutlinedButton(style: style, onPressed: onTap, child: child),
    );
  }
}
