import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../models/help.dart';
import '../../router.dart';
import '../../state/app_scope.dart';
import '../../ui/history.dart';
import '../../ui/surfaces.dart';
import '../../ui/visuals.dart';
import '../../utils/format.dart';
import 'request_actions.dart';

/// One request and the trip it is taking to a helper, step by step.
class RequestScreen extends StatelessWidget {
  const RequestScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);

    return ValueListenableBuilder<List<HelpRequest>>(
      valueListenable: scope.repository.requests,
      builder: (context, requests, _) {
        final r = requests.where((r) => r.id == id).firstOrNull;
        if (r == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(l.requestNotFound)),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(l.requestTitle(r))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _Header(request: r),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  l.progressTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
              _Timeline(request: r),
              if (r.note.isNotEmpty || r.locationNote.isNotEmpty) ...[
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    l.detailsTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                if (r.locationNote.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(r.locationNote),
                  ),
                if (r.note.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notes),
                    title: Text(r.note),
                  ),
              ],
              const SizedBox(height: 16),
              SignedHistory(subject: r.id),
            ],
          ),
          bottomNavigationBar: _Actions(request: r),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.request});

  final HelpRequest request;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final r = request;
    final (bg, fg) = urgencyColors(r.urgency, c);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: bg,
              foregroundColor: fg,
              child: Icon(requestIcon(r), size: 34),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(urgencyIcon(r.urgency), size: 20),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          l.urgency(r.urgency),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    [
                      l.peopleCount(r.people),
                      l.timeAgo(r.createdAt),
                      if (!r.mine) l.fromName(r.senderName),
                    ].join('  ·  '),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The stages as a vertical line: done, current, and still to come.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.request});

  final HelpRequest request;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final r = request;
    // Resolved is shown only once reached.
    final stages = RequestStage.values
        .where((s) => s != RequestStage.resolved || r.stage == s)
        .toList();

    return Column(
      children: [
        for (final (i, s) in stages.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 48,
                  child: Column(
                    children: [
                      _StageDot(
                        icon: stageIcon(s),
                        done: s.index < r.stage.index,
                        current: s == r.stage,
                      ),
                      if (i < stages.length - 1)
                        Expanded(
                          child: Container(
                            width: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: s.index < r.stage.index ? c.primary : c.outlineVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.stage(s, mine: r.mine),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: s.index <= r.stage.index
                                ? c.onSurface
                                : c.onSurfaceVariant,
                            fontWeight: s == r.stage ? FontWeight.w700 : null,
                          ),
                        ),
                        Text(
                          s.index <= r.stage.index
                              ? [
                                  l.stageDetail(s, r),
                                  if (r.stageTimes[s] case final t?)
                                    clockTime(t),
                                ].join('  ·  ')
                              : l.stageWaiting,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StageDot extends StatelessWidget {
  const _StageDot({
    required this.icon,
    required this.done,
    required this.current,
  });

  final IconData icon;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final (bg, fg) = done
        ? (c.primary, c.onPrimary)
        : current
            ? (c.primaryContainer, c.onPrimaryContainer)
            : (c.surfaceContainerHighest, c.outline);

    final dot = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: current ? Border.all(color: c.primary, width: 2) : null,
      ),
      child: Icon(done ? Icons.check : icon, size: 20, color: fg),
    );
    // The current stage pulses while it waits on the network.
    return SizedBox(
      width: 48,
      height: 48,
      child: current ? Pulse(color: c.primary, size: 48, rings: 1, child: dot) : Center(child: dot),
    );
  }
}

/// One or two main actions, always at the bottom.
class _Actions extends StatelessWidget {
  const _Actions({required this.request});

  final HelpRequest request;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = request;

    final (primary, secondary) = switch (r) {
      HelpRequest(mine: true) => (
          FilledButton.icon(
            onPressed: () => context.push('${requestPath(r.id)}/card'),
            icon: const Icon(Icons.translate),
            label: Text(l.showToResponder),
          ),
          OutlinedButton(
            onPressed: () {
              cancelMyRequest(context, r);
              context.go('/more/requests');
            },
            child: Text(l.cancelRequest),
          ),
        ),
      HelpRequest(helpingIsMe: true) => (
          OutlinedButton.icon(
            onPressed: () => stopHelping(context, r),
            icon: const Icon(Icons.cancel_outlined),
            label: Text(l.stopHelping),
          ),
          null,
        ),
      HelpRequest(isOpen: true) => (
          FilledButton.icon(
            onPressed: () => acceptRequest(context, r),
            icon: const Icon(Icons.volunteer_activism),
            label: Text(l.iCanHelp),
          ),
          null,
        ),
      _ => (null, null),
    };
    if (primary == null) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
