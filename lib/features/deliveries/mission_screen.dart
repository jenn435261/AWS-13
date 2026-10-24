import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../models/mission.dart';
import '../../router.dart';
import '../../state/app_scope.dart';
import '../../ui/theme.dart';
import '../../ui/visuals.dart';
import '../../ui/history.dart';

/// One mission. Exact addresses appear only for its carrier, who holds the
/// mission's capability; everyone else sees place names (Spec 23 and 28).
class MissionScreen extends StatelessWidget {
  const MissionScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return ValueListenableBuilder<List<Mission>>(
      valueListenable: scope.repository.missions,
      builder: (context, missions, _) {
        final m = missions.where((m) => m.id == id).firstOrNull;
        if (m == null) {
          return Scaffold(appBar: AppBar(), body: Center(child: Text(l.requestNotFound)));
        }
        final exact = m.carrierIsMe && m.stage != MissionStage.delivered;

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
              _Stages(mission: m),
              const SizedBox(height: 8),
              SignedHistory(subject: m.id),
            ],
          ),
          bottomNavigationBar: _Actions(mission: m),
        );
      },
    );
  }
}

class _Stages extends StatelessWidget {
  const _Stages({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final m = mission;
    const order = [
      MissionStage.assigned,
      MissionStage.inTransit,
      MissionStage.awaitingHandoff,
      MissionStage.delivered,
    ];
    final current = m.handedOff ? MissionStage.delivered.index : m.stage.index;

    return Column(
      children: [
        for (final s in order)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              s.index < current
                  ? Icons.check_circle
                  : s.index == current
                      ? missionStageIcon(s)
                      : Icons.radio_button_unchecked,
              color: s.index <= current ? c.primary : c.outline,
            ),
            title: Text(
              l.missionStage(s),
              style: TextStyle(
                fontWeight: s.index == current ? FontWeight.w700 : null,
                color: s.index <= current ? c.onSurface : c.onSurfaceVariant,
              ),
            ),
          ),
      ],
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
    if (primary == null) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8 + helpButtonClearance),
        child: Row(
          children: [
            if (secondary != null) ...[
              Expanded(child: secondary),
              const SizedBox(width: 12),
            ],
            Expanded(flex: 2, child: primary),
          ],
        ),
      ),
    );
  }
}
