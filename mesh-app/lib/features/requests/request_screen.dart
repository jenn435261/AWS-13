import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../models/help.dart';
import '../../router.dart';
import '../../state/app_scope.dart';
import '../../ui/action_bar.dart';
import '../../ui/advanced_section.dart';
import '../../ui/empty_state.dart';
import '../../ui/history.dart';
import '../../ui/stage_list.dart';
import '../../ui/visuals.dart';
import '../../utils/format.dart';
import 'request_actions.dart';

/// One request and the trip it is taking to a helper, step by step, in
/// plain words. How it travelled (radio hops, the server check, the signed
/// history) is under Advanced.
class RequestScreen extends StatelessWidget {
  const RequestScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([repo.requests, repo.events]),
      builder: (context, _) {
        final r = repo.requests.value.where((r) => r.id == id).firstOrNull;
        if (r == null) return NotFoundScaffold(message: l.requestNotFound);
        final reached = r.stage.index;
        final signed = repo.events.value.any((e) => e.subject == r.id);

        return Scaffold(
          appBar: AppBar(title: Text(l.requestTitle(r))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _Header(request: r),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(l.progressTitle, style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: 8),
              StageList(
                stages: _stages(l, r),
                waiting: r.stage != RequestStage.resolved,
              ),
              if (r.note.isNotEmpty || r.locationNote.isNotEmpty) ...[
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(l.detailsTitle, style: theme.textTheme.titleLarge),
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
              if (signed || reached >= RequestStage.mesh.index) ...[
                const SizedBox(height: 8),
                AdvancedSection(
                  subtitle: l.lookRequestAdvancedSub,
                  children: [
                    if (reached >= RequestStage.mesh.index)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(stageIcon(RequestStage.mesh)),
                        title: Text(l.stageMesh),
                        subtitle: Text(l.stageMeshSub(r.hops)),
                      ),
                    if (reached >= RequestStage.verified.index)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(stageIcon(RequestStage.verified)),
                        title: Text(l.stageVerified),
                        subtitle: Text(l.stageVerifiedSub),
                      ),
                    const SizedBox(height: 8),
                    SignedHistory(subject: r.id),
                  ],
                ),
              ],
            ],
          ),
          bottomNavigationBar: _Actions(request: r),
        );
      },
    );
  }

  /// Resolved is shown only once reached.
  static List<StageItem> _stages(AppLocalizations l, HelpRequest r) => [
        for (final s in RequestStage.values)
          if (s != RequestStage.resolved || r.stage == s)
            StageItem(
              icon: stageIcon(s),
              title: plainStageTitle(l, s, mine: r.mine),
              state: s.index < r.stage.index || r.stage == RequestStage.resolved
                  ? StageState.done
                  : s == r.stage
                      ? StageState.current
                      : StageState.upcoming,
              detail: s.index <= r.stage.index
                  ? [
                      plainStageDetail(l, s, r),
                      if (r.stageTimes[s] case final t?) clockTime(t),
                    ].join('  ·  ')
                  : l.stageWaiting,
            ),
      ];
}

/// A request's stage in words anyone understands (rule 4): "Sent" and
/// "Received" instead of "Sent over the mesh" and "Checked by the server".
/// Lists and map cards can use this too.
String plainStageTitle(AppLocalizations l, RequestStage s, {bool mine = true}) => switch (s) {
      RequestStage.mesh => l.lookStageSent,
      RequestStage.verified => l.lookStageReceived,
      _ => l.stage(s, mine: mine),
    };

/// The line under [plainStageTitle]. Hops and the server check are left to
/// the Advanced section.
String plainStageDetail(AppLocalizations l, RequestStage s, HelpRequest r) => switch (s) {
      RequestStage.mesh => l.lookStageSentSub,
      RequestStage.verified => l.lookStageReceivedSub,
      _ => l.stageDetail(s, r),
    };

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

/// One or two main actions, always at the bottom.
class _Actions extends StatelessWidget {
  const _Actions({required this.request});

  final HelpRequest request;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = request;

    final (Widget? primary, Widget? secondary) = switch (r) {
      HelpRequest(mine: true) => (
          FilledButton.icon(
            onPressed: () => context.push('${requestPath(r.id)}/card'),
            icon: const Icon(Icons.translate),
            label: Text(l.showToResponder),
          ),
          OutlinedButton(
            onPressed: () {
              cancelMyRequest(context, r);
              // Back to wherever the request was opened from.
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/more/requests');
              }
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
    return ActionBar(primary: primary, secondary: secondary);
  }
}
