import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mesh_repository.dart';
import '../../l10n/labels.dart';
import '../../models/help.dart';
import '../../router.dart';
import '../../state/app_scope.dart';
import '../../state/drafts.dart';
import '../../ui/feedback.dart';
import '../../ui/hold_button.dart';
import '../../ui/step_scaffold.dart';
import '../../ui/visuals.dart';
import '../shell/help_button.dart';

/// Asking for help in two taps plus optional detail (Spec sections 4 and 5):
/// pick a category (that moves on by itself), then send. The category
/// travels first as a few bytes; the free text follows when there is room.

const _steps = ['/help', '/help/details'];

void openRequestFlow(BuildContext context) {
  final router = GoRouter.of(context);
  final scope = AppScope.of(context);
  // An Undo left over from the last request must not overwrite this one.
  scope.feedback.messengerKey.currentState?.hideCurrentSnackBar();
  scope.requestDraft.returnTo =
      router.routerDelegate.currentConfiguration.uri.toString();
  router.push(_steps.first);
}

/// Pushes the steps one by one, so Back still walks through each of them.
void _reopen(GoRouter router, int step) {
  for (final path in _steps.take(step)) {
    router.push(path);
  }
}

/// Closes the flow. A started request can be brought back with Undo.
void _close(BuildContext context, int step) {
  final scope = AppScope.of(context);
  final l = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final draft = scope.requestDraft;
  final saved = draft.copy()..lastStep = step;

  router.go(draft.returnTo);
  if (saved.isEmpty) return;
  draft.reset();
  scope.feedback.toast(
    l.requestDiscarded,
    icon: Icons.delete_outline,
    actionLabel: l.undo,
    onAction: () {
      if (!draft.isEmpty) return;
      draft.restoreFrom(saved);
      _reopen(router, step);
    },
  );
}

class HelpKindStep extends StatelessWidget {
  const HelpKindStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final draft = AppScope.of(context).requestDraft;

    void next() {
      draft.lastStep = 2;
      context.push(_steps[1]);
    }

    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => StepScaffold(
        step: 1,
        total: 2,
        title: l.helpStep1Title,
        actionLabel: l.next,
        onAction: draft.kind == null ? null : next,
        onClose: () => _close(context, 1),
        children: [
          const _SosStrip(),
          const SizedBox(height: 16),
          for (final kind in HelpKind.values) ...[
            ChoiceTile(
              icon: helpKindIcon(kind),
              hue: helpKindHue(kind),
              title: l.helpKind(kind),
              subtitle: l.helpKindSub(kind),
              selected: draft.kind == kind,
              onTap: () {
                Haptics.tick();
                draft.kind = kind;
                next();
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Hold-for-SOS, for anyone who can't answer questions right now.
class _SosStrip extends StatelessWidget {
  const _SosStrip();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final theme = Theme.of(context);

    return HoldButton(
      semanticsLabel: l.holdForSos,
      semanticsHint: l.holdForSosSub,
      onTap: () => scope.feedback.toast(l.keepHolding, icon: Icons.touch_app_outlined),
      onHeld: () => sendSos(context),
      builder: (context, progress) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: sosRed,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          children: [
            // Fills left to right while held.
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(Icons.sos, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.holdForSos,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          l.holdForSosSub,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.touch_app, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 2: the note first, then everything else already filled in.
class HelpDetailsStep extends StatefulWidget {
  const HelpDetailsStep({super.key});

  @override
  State<HelpDetailsStep> createState() => _HelpDetailsStepState();
}

class _HelpDetailsStepState extends State<HelpDetailsStep> {
  late final RequestDraft _draft = AppScope.of(context).requestDraft;
  late final _locationNote = TextEditingController(text: _draft.locationNote);
  late final _note = TextEditingController(text: _draft.note);

  @override
  void dispose() {
    _locationNote.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final saved = _draft.copy()..lastStep = 2;

    final HelpRequest request;
    try {
      request = await scope.repository.submitRequest(_draft, from: scope.auth.me);
    } on DraftRejected catch (e) {
      scope.feedback.toast(l.problem(e.problems.first), icon: Icons.error_outline, strong: true);
      return;
    }

    _draft.reset();
    router.go(requestPath(request.id));
    scope.feedback.toast(
      l.requestSent,
      icon: Icons.send,
      actionLabel: l.undo,
      onAction: () async {
        // Undo takes the request back and reopens it for changes, unless a
        // new request has been started since.
        if (!_draft.isEmpty) return;
        await scope.repository.cancelRequest(request.id);
        _draft.restoreFrom(saved);
        router.go(saved.returnTo);
        WidgetsBinding.instance.addPostFrameCallback((_) => _reopen(router, 2));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final fix = AppScope.of(context).repository.location.value;

    Widget question(String text) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Text(text, style: theme.textTheme.titleMedium),
        );

    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) {
        final kind = _draft.kind;
        final suggested = suggestKind(_draft.note);
        final problems = _draft.problems(hasLocation: fix != null);

        return StepScaffold(
          step: 2,
          total: 2,
          title: l.helpStep2Title,
          actionLabel: l.sendRequest,
          actionIcon: Icons.send,
          actionColor: sosRed,
          onAction: problems.isEmpty ? _send : null,
          onClose: () => _close(context, 2),
          children: [
            if (kind != null)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Icon(helpKindIcon(kind), size: 28),
                  title: Text(l.helpKind(kind)),
                  trailing: TextButton(
                    onPressed: () => context.pop(),
                    child: Text(l.edit),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLength: maxNoteLength,
              minLines: 2,
              maxLines: 4,
              onChanged: _draft.setNote,
              decoration: InputDecoration(
                labelText: l.noteLabel,
                hintText: l.noteExampleHint,
                prefixIcon: const Icon(Icons.notes),
              ),
            ),
            if (suggested != null && suggested != kind)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: c.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.suggestion(l.helpKind(suggested)))),
                    TextButton(
                      onPressed: () {
                        Haptics.tick();
                        _draft.kind = suggested;
                      },
                      child: Text(l.useSuggestion),
                    ),
                  ],
                ),
              ),
            Text(
              l.structuredFirst,
              style: TextStyle(color: c.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            question(l.urgencyQuestion),
            for (final u in Urgency.values) ...[
              ChoiceTile(
                icon: urgencyIcon(u),
                hue: urgencyHue(u),
                title: l.urgency(u),
                subtitle: l.urgencySub(u),
                selected: _draft.urgency == u,
                onTap: () {
                  Haptics.tick();
                  _draft.urgency = u;
                },
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            question(l.peopleQuestion),
            _PeopleStepper(
              value: _draft.people,
              onChanged: (v) {
                Haptics.tick();
                _draft.people = v;
              },
            ),
            const SizedBox(height: 20),
            question(l.locationTitle),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                fix == null ? Icons.location_off_outlined : Icons.my_location,
                color: fix == null ? c.error : c.primary,
              ),
              title: Text(
                fix == null ? l.locationMissing : l.locationAuto(fix.accuracyMeters.round()),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _locationNote,
              maxLength: maxNoteLength,
              onChanged: (v) {
                _draft.locationNote = v;
                if (fix == null) setState(() {});
              },
              decoration: InputDecoration(
                labelText: l.locationNoteLabel,
                hintText: l.locationNoteHint,
                prefixIcon: const Icon(Icons.edit_location_alt_outlined),
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

class _PeopleStepper extends StatelessWidget {
  const _PeopleStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const size = Size(64, 64);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            IconButton.filledTonal(
              tooltip: l.fewerPeople,
              style: IconButton.styleFrom(minimumSize: size),
              onPressed: value > 1 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove, size: 30),
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l.peopleCount(value),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: l.morePeople,
              style: IconButton.styleFrom(minimumSize: size),
              onPressed: value < maxPeople ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}
