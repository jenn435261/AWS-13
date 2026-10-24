import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../models/mission.dart';
import '../../router.dart';
import '../../state/app_scope.dart';
import '../../ui/action_bar.dart';
import '../../ui/advanced_section.dart';
import '../../ui/empty_state.dart';
import '../../ui/history.dart';
import '../../ui/stage_list.dart';
import '../../ui/visuals.dart';
import '../../utils/format.dart';

/// One mission. Exact addresses appear only for its carrier, who holds the
/// mission's capability; everyone else sees place names (Spec 23 and 28).
///
/// This phone's location is shared only while it carries the package, and
/// the screen says so for exactly that long.
class MissionScreen extends StatelessWidget {
  const MissionScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return ListenableBuilder(
      listenable: Listenable.merge([repo.missions, repo.sharingLocation, repo.events]),
      builder: (context, _) {
        final m = repo.missions.value.where((m) => m.id == id).firstOrNull;
        if (m == null) {
          return NotFoundScaffold(
            icon: Icons.local_shipping_outlined,
            message: l.missionNotFound,
          );
        }
        final exact = m.carrierIsMe && m.stage != MissionStage.delivered;
        final sharing = repo.sharingLocation.value && _carrying(m);
        final signed = repo.events.value.any((e) => e.subject == m.id);

        Widget place(IconData icon, String label, String name, String address) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, size: 28),
              title: Text(label, style: theme.textTheme.titleMedium),
              subtitle: Text(exact ? '$name\n$address' : '$name\n${l.exactHidden}'),
            );

        return Scaffold(
          appBar: AppBar(title: Text(l.missionTitle(m.id))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: m.priority == Priority.high ? sosRed : c.secondaryContainer,
                        foregroundColor:
                            m.priority == Priority.high ? Colors.white : c.onSecondaryContainer,
                        child: const Icon(Icons.inventory_2, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${m.item}, ${m.quantity}', style: theme.textTheme.titleLarge),
                            Text(
                              '${l.priority(m.priority)}  ·  ${l.packageLabel(m.packageId)}',
                              style: TextStyle(color: c.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (sharing) ...[
                const SizedBox(height: 12),
                const SharingLocationNotice(),
              ],
              const SizedBox(height: 12),
              place(Icons.storefront_outlined, l.pickupLabel, m.pickup, m.pickupExact),
              place(Icons.flag_outlined, l.destinationLabel, m.destination, m.destinationExact),
              if (m.carrier != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline, size: 28),
                  title: Text(l.carrierLabel, style: theme.textTheme.titleMedium),
                  subtitle: Text(m.handedOff ? l.handedOffTo(m.carrier!) : m.carrier!),
                ),
              const SizedBox(height: 8),
              StageList(
                stages: _missionStages(l, m),
                waiting: m.stage == MissionStage.awaitingHandoff && !m.handedOff,
              ),
              if (signed)
                AdvancedSection(
                  subtitle: l.historyTitle,
                  children: [SignedHistory(subject: m.id)],
                ),
            ],
          ),
          bottomNavigationBar: _Actions(mission: m),
        );
      },
    );
  }
}

/// Whether this phone has the package right now.
bool _carrying(Mission m) =>
    m.carrierIsMe && !m.handedOff && m.stage != MissionStage.delivered;

/// A delivery's stages, for [StageList]. Once delivered every stage is
/// done. A package this phone handed off is done up to the handoff; the
/// delivery itself is now the next driver's.
List<StageItem> _missionStages(AppLocalizations l, Mission m) {
  const order = [
    MissionStage.assigned,
    MissionStage.inTransit,
    MissionStage.awaitingHandoff,
    MissionStage.delivered,
  ];
  final (reached, finished) = m.handedOff
      ? (MissionStage.awaitingHandoff.index, true)
      : (m.stage.index, m.stage == MissionStage.delivered);
  return [
    for (final s in order)
      StageItem(
        icon: missionStageIcon(s),
        title: l.missionStage(s),
        state: s.index < reached || (s.index == reached && finished)
            ? StageState.done
            : s.index == reached
                ? StageState.current
                : StageState.upcoming,
        detail: switch (m.stageTimes[s]) {
          final t? when s.index <= reached => clockTime(t),
          _ => null,
        },
      ),
  ];
}

/// Shown while this phone carries the package, the only time its location
/// leaves the phone. Read out when it appears.
class SharingLocationNotice extends StatelessWidget {
  const SharingLocationNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.primaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.share_location, color: c.onPrimaryContainer, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.deliverySharingLocation,
                  style: theme.textTheme.titleMedium?.copyWith(color: c.onPrimaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One or two main actions for the mission's current step.
class _Actions extends StatelessWidget {
  const _Actions({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = mission;

    Future<void> accept() => scope.undoable(
          context,
          message: l.missionAccepted,
          undone: l.missionReleased,
          icon: Icons.handshake_outlined,
          run: () => scope.repository.acceptMission(m.id, carrier: scope.auth.me),
          revert: () => scope.repository.releaseMission(m.id),
        );

    final (Widget? primary, Widget? secondary) = switch (m) {
      Mission(stage: MissionStage.available) => (
          FilledButton.icon(
            onPressed: accept,
            icon: const Icon(Icons.handshake_outlined),
            label: Text(l.acceptMission),
          ),
          null,
        ),
      Mission(stage: MissionStage.assigned, carrierIsMe: true) => (
          FilledButton.icon(
            onPressed: () => context.push('${missionPath(m.id)}/scan'),
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(l.confirmPickup),
          ),
          OutlinedButton(
            onPressed: () => context.push('${missionPath(m.id)}/code'),
            child: Text(l.packageCode),
          ),
        ),
      Mission(stage: MissionStage.inTransit, carrierIsMe: true) => (
          FilledButton.icon(
            onPressed: () => context.push('${missionPath(m.id)}/scan'),
            icon: const Icon(Icons.task_alt),
            label: Text(l.confirmDelivery),
          ),
          OutlinedButton(
            onPressed: () {
              scope.repository.startHandoff(m.id);
              context.push('${missionPath(m.id)}/code');
            },
            child: Text(l.handOff),
          ),
        ),
      Mission(stage: MissionStage.awaitingHandoff) => (
          OutlinedButton.icon(
            onPressed: () => context.push('${missionPath(m.id)}/code'),
            icon: const Icon(Icons.qr_code_2),
            label: Text(l.handoffWaiting, maxLines: 2),
          ),
          null,
        ),
      _ => (null, null),
    };

    return ActionBar(
      primary: primary,
      secondary: secondary,
      // Before taking a delivery, say what accepting shares.
      note: m.stage == MissionStage.available
          ? Row(
              children: [
                Icon(Icons.location_on_outlined, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.deliveryLocationOnlyWhileCarrying,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
