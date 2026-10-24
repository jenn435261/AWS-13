import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../models/mission.dart';
import '../../models/role.dart';
import '../../router.dart';
import '../../state/app_scope.dart';
import '../../ui/theme.dart';
import '../../ui/visuals.dart';
import '../help/offer_flow.dart';

/// Whether Deliveries shows up at all (Spec section 64): when this person
/// offers transport, distributes for an organization, or has a mission.
bool deliveriesVisible(AppScope scope) =>
    (scope.repository.offer.value?.offersTransport ?? false) ||
    scope.auth.role.atLeast(Role.manager) ||
    scope.repository.missions.value.any((m) => m.carrierIsMe || m.handedOff);

/// Missions, sorted the way a driver thinks about them.
class DeliveriesScreen extends StatelessWidget {
  const DeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        scope.repository.missions,
        scope.repository.offer,
        scope.auth,
      ]),
      builder: (context, _) {
        final missions = scope.repository.missions.value;
        // Available missions are only for people who can carry them.
        final canCarry = (scope.repository.offer.value?.offersTransport ?? false) ||
            scope.auth.role.atLeast(Role.manager);
        final tabs = <(String, List<Mission>)>[
          (
            l.tabAvailable,
            canCarry ? missions.where((m) => m.stage == MissionStage.available).toList() : const [],
          ),
          (
            l.tabAssigned,
            missions.where((m) => m.carrierIsMe && m.stage == MissionStage.assigned).toList(),
          ),
          (
            l.tabInTransit,
            missions.where((m) => m.carrierIsMe && m.stage == MissionStage.inTransit).toList(),
          ),
          (
            l.tabHandoff,
            missions.where((m) => m.stage == MissionStage.awaitingHandoff).toList(),
          ),
          (
            l.tabCompleted,
            missions
                .where((m) => m.stage == MissionStage.delivered || m.handedOff)
                .toList(),
          ),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l.deliveries),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  for (final (label, list) in tabs) Tab(text: '$label (${list.length})'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                for (final (i, (_, list)) in tabs.indexed)
                  list.isEmpty
                      ? _Empty(showOffer: i == 0 && !canCarry)
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, helpButtonClearance + 16),
                          children: [
                            for (final m in list) ...[
                              MissionTile(mission: m),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.showOffer});

  final bool showOffer;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(showOffer ? l.deliveriesHint : l.noMissions, textAlign: TextAlign.center),
            if (showOffer) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => openOfferFlow(context),
                icon: const Icon(Icons.volunteer_activism),
                label: Text(l.canHelp),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MissionTile extends StatelessWidget {
  const MissionTile({super.key, required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final m = mission;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(missionPath(m.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: m.priority == Priority.high ? sosRed : c.secondaryContainer,
                foregroundColor: m.priority == Priority.high ? Colors.white : c.onSecondaryContainer,
                child: Icon(missionStageIcon(m.stage)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l.missionTitle(m.id)}: ${m.item}, ${m.quantity}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${m.pickup}  →  ${m.destination}',
                      style: TextStyle(color: c.onSurfaceVariant),
                    ),
                    Text(
                      m.handedOff
                          ? l.handedOffTo(m.carrier ?? '')
                          : '${l.missionStage(m.stage)}  ·  ${l.priority(m.priority)}',
                      style: TextStyle(color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
