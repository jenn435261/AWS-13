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
/// pick a category (that moves on by itself), then say how urgent and send.
/// The category travels first as a few bytes; the free text follows when
/// there is room.

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

/// Back to the screen the flow was opened from.
void _leave(GoRouter router, String returnTo) =>
    leaveFlow(router, _steps.first, fallback: returnTo);

/// Closes the flow. A started request can be brought back with Undo, and
/// discarded again with Redo.
void _close(BuildContext context, int step) {
  final scope = AppScope.of(context);
  final l = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final draft = scope.requestDraft;
  final saved = draft.copy()..lastStep = step;

  if (saved.isEmpty) {
    _leave(router, saved.returnTo);
    return;
  }
  // False once a newer request was started: Undo never overwrites it.
  var ours = true;
  scope.undoable(
    context,
    message: l.requestDiscarded,
    undone: l.requestRestored,
    icon: Icons.delete_outline,
    run: () async {
      if (!ours) return;
      _leave(router, saved.returnTo);
      draft.reset();
    },
    revert: () async {
      ours = draft.isEmpty;
      if (!ours) return;
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
      onHeld: () {
        final router = GoRouter.of(context);
        // The SOS takes the place of the request being filled in: its
        // screen opens over the one the flow was opened from.
        sendSos(context);
        _leave(router, scope.requestDraft.returnTo);
      },
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

/// Step 2 asks one thing: how urgent. The location field shows only when
/// the phone has no location, and is required then. The note and the number
/// of people wait behind "Add details".
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
    final draft = _draft;
    final saved = draft.copy()..lastStep = 2;

    final HelpRequest request;
    try {
      request = await scope.repository.submitRequest(draft, from: scope.auth.me);
    } on DraftRejected catch (e) {
      scope.feedback.toast(l.problem(e.problems.first), icon: Icons.error_outline, strong: true);
      return;
    }
    if (!mounted) return;

    // Undo takes the request back and reopens it for changes, unless a new
    // request has been started since. Redo sends it again.
    var sent = true;
    var ours = true;
    await scope.undoable(
      context,
      message: l.requestSent,
      undone: l.navRequestTakenBack,
      icon: Icons.send,
      run: () async {
        if (!sent) {
          await scope.repository.restoreRequest(request);
          sent = true;
        }
        if (!ours) return;
        // Pushed over the screen the flow was opened from, so Back
        // returns there.
        _leave(router, saved.returnTo);
        router.push(requestPath(request.id));
        draft.reset();
      },
      revert: () async {
        await scope.repository.cancelRequest(request.id);
        sent = false;
        ours = draft.isEmpty;
        if (!ours) return;
        draft.restoreFrom(saved);
        if (router.state.uri.path == requestPath(request.id) && router.canPop()) {
          router.pop();
        }
        _reopen(router, 2);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final location = AppScope.of(context).repository.location;

    return ListenableBuilder(
      listenable: Listenable.merge([_draft, location]),
      builder: (context, _) {
        final kind = _draft.kind;
        final fix = location.value;
        final problems = _draft.problems(hasLocation: fix != null);

        return StepScaffold(
          step: 2,
          total: 2,
          title: l.urgencyQuestion,
          actionLabel: l.sendRequest,
          actionIcon: Icons.send,
          actionColor: sosRed,
          onAction: problems.isEmpty ? _send : null,
          onClose: () => _close(context, 2),
          children: [
            if (kind != null) ...[
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
            ],
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
            const SizedBox(height: 8),
            if (fix == null) ...[
              // The manual fallback: with no location, the person says where.
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.location_off_outlined, color: c.error),
                title: Text(l.locationMissing),
              ),
              TextField(
                key: const ValueKey('request-location'),
                controller: _locationNote,
                maxLength: maxNoteLength,
                onChanged: _draft.setLocationNote,
                decoration: InputDecoration(
                  labelText: l.locationNoteLabel,
                  hintText: l.locationNoteHint,
                  prefixIcon: const Icon(Icons.edit_location_alt_outlined),
                ),
              ),
            ] else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.my_location, color: c.primary),
                title: Text(
                  fix.source == LocationSource.manual && fix.label.isNotEmpty
                      ? l.navLocationTyped(fix.label)
                      : l.locationAuto(fix.accuracyMeters.round()),
                ),
              ),
            const SizedBox(height: 8),
            _MoreDetails(draft: _draft, note: _note),
            // The location field already says what is missing there.
            for (final p in problems)
              if (p != DraftProblem.missingLocation)
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

/// The optional parts of a request, folded away until asked for: a note
/// (which can suggest a better category) and how many people need help.
class _MoreDetails extends StatelessWidget {
  const _MoreDetails({required this.draft, required this.note});

  final RequestDraft draft;
  final TextEditingController note;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final kind = draft.kind;
    final suggested = suggestKind(draft.note);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // Already open when a restored request has details in it.
        initiallyExpanded: draft.note.isNotEmpty || draft.people != 1,
        leading: const Icon(Icons.add_comment_outlined),
        title: Text(l.navAddDetails),
        subtitle: Text(l.navAddDetailsSub),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('request-note'),
            controller: note,
            maxLength: maxNoteLength,
            minLines: 2,
            maxLines: 4,
            onChanged: draft.setNote,
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
                      draft.kind = suggested;
                    },
                    child: Text(l.useSuggestion),
                  ),
                ],
              ),
            ),
          Text(l.structuredFirst, style: TextStyle(color: c.onSurfaceVariant)),
          const SizedBox(height: 20),
          Text(l.peopleQuestion, style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          _PeopleStepper(
            value: draft.people,
            onChanged: (v) {
              Haptics.tick();
              draft.people = v;
            },
          ),
        ],
      ),
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
