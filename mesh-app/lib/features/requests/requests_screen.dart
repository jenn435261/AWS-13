import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../data/demo_area.dart';
import '../../l10n/labels.dart';
import '../../models/help.dart';
import '../../router.dart';
import '../../state/app_scope.dart';
import '../../ui/surfaces.dart';
import '../../ui/theme.dart';
import '../../ui/visuals.dart';
import '../../utils/format.dart';
import '../help/offer_flow.dart';
import '../shell/bottom_actions.dart';
import 'request_actions.dart';

/// Requests near you and your own, as two tabs you can swipe between. One
/// main action at the bottom: offering help. A request opens with a tap;
/// holding it shows quick actions, such as "I can help".
class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final l = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        repo.requests,
        repo.loading,
        repo.offer,
        repo.location,
      ]),
      builder: (context, _) {
        final all = repo.requests.value;
        final here = repo.location.value?.point ?? demoCenter;
        final nearby = [
          for (final r in all)
            if (!r.mine && (r.isOpen || r.helpingIsMe)) r,
        ]..sort((a, b) => _distance(here, a).compareTo(_distance(here, b)));
        final mine = [for (final r in all) if (r.mine) r];

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l.myRequests),
              bottom: TabBar(
                tabs: [
                  Tab(text: '${l.tabNearMe} (${nearby.length})'),
                  Tab(text: '${l.tabMine} (${mine.length})'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _RequestList(
                  loading: repo.loading.value,
                  requests: nearby,
                  here: here,
                  empty: l.noNearby,
                  header: const _OfferCard(),
                ),
                _RequestList(
                  loading: repo.loading.value,
                  requests: mine,
                  here: here,
                  empty: l.noMine,
                ),
              ],
            ),
            bottomNavigationBar: BottomActions(
              main: MainButton(
                label: repo.offer.value == null ? l.canHelp : l.navChangeOffer,
                icon: Icons.volunteer_activism,
                onPressed: () => openOfferFlow(context),
              ),
            ),
          ),
        );
      },
    );
  }

  static double _distance(LatLng here, HelpRequest r) =>
      r.location == null ? double.infinity : metersBetween(here, r.location!);
}


class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.loading,
    required this.requests,
    required this.here,
    required this.empty,
    this.header,
  });

  final bool loading;
  final List<HelpRequest> requests;
  final LatLng here;
  final String empty;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final padding = EdgeInsets.fromLTRB(16, 16, 16, bottomClearance(context));

    if (loading) {
      final fake = HelpRequest(
        id: '',
        kind: HelpKind.medical,
        urgency: Urgency.now,
        people: 2,
        createdAt: DateTime.now(),
        senderName: 'Someone',
      );
      return Skeletonizer(
        child: ListView(
          padding: padding,
          children: [
            for (var i = 0; i < 4; i++) ...[
              RequestTile(request: fake),
              const SizedBox(height: 12),
            ],
          ],
        ),
      );
    }

    return ListView(
      padding: padding,
      children: [
        if (header != null) ...[header!, const SizedBox(height: 16)],
        if (requests.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(empty, textAlign: TextAlign.center),
              ],
            ),
          ),
        for (final r in requests) ...[
          RequestTile(
            request: r,
            distance: r.location == null || r.mine
                ? null
                : l.distance(metersBetween(here, r.location!)),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// One request in a list. Tap to open, hold for quick actions.
class RequestTile extends StatelessWidget {
  const RequestTile({super.key, required this.request, this.distance});

  final HelpRequest request;
  final String? distance;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final r = request;
    final (bg, fg) = urgencyColors(r.urgency, c);
    final meta = [
      if (distance != null) distance!,
      l.peopleCount(r.people),
      l.timeAgo(r.createdAt),
    ].join('  ·  ');

    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Pushed, so Back returns to this list.
        onTap: () => context.push(requestPath(r.id)),
        onLongPress: () => showRequestActions(context, r),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: bg,
                    foregroundColor: fg,
                    child: Icon(requestIcon(r)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.requestTitle(r),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          meta,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: c.onSurfaceVariant),
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
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Badge(icon: urgencyIcon(r.urgency), text: l.urgency(r.urgency)),
                  _Badge(icon: stageIcon(r.stage), text: l.stage(r.stage, mine: r.mine)),
                ],
              ),
              if (r.mine) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (r.stage.index + 1) / RequestStage.values.length,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    // "I can help" is a hold away, not a button on every card.
    return Semantics(
      onTapHint: l.openDetails,
      onLongPressHint: l.navHoldForMore,
      child: card,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: c.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

/// Says what you're offering, or invites you to offer help with the main
/// action below. Stopping an offer is the one small action here.
class _OfferCard extends StatelessWidget {
  const _OfferCard();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final offer = scope.repository.offer.value;

    return Card(
      color: c.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.volunteer_activism, color: c.onPrimaryContainer, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                offer == null ? l.offerPrompt : l.offeringList(l.supplies(offer.kinds)),
                style: TextStyle(color: c.onPrimaryContainer),
              ),
            ),
            if (offer != null)
              TextButton(
                onPressed: () => scope.undoable(
                  context,
                  message: l.offerStopped,
                  undone: l.offeringStarted,
                  run: () => scope.repository.setOffer(null),
                  revert: () => scope.repository.setOffer(offer),
                ),
                child: Text(l.stopOffering),
              ),
          ],
        ),
      ),
    );
  }
}
