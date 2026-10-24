import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import 'surfaces.dart';

/// Where a stage is on the way to done.
enum StageState { done, current, upcoming }

/// One stage in a [StageList].
class StageItem {
  const StageItem({
    required this.icon,
    required this.title,
    required this.state,
    this.detail,
  });

  final IconData icon;
  final String title;
  final StageState state;

  /// A line under the title, such as who accepted and when.
  final String? detail;
}

/// Progress as a vertical line of stages, for requests and deliveries alike.
/// Done stages carry a check, the current one is outlined, the rest are
/// grey. State is never shown by color alone: each stage has its own icon,
/// the current title is bold, and a screen reader hears "Done", "Now" or
/// "Not yet" before each title.
class StageList extends StatelessWidget {
  const StageList({super.key, required this.stages, this.waiting = false});

  final List<StageItem> stages;

  /// The current stage is waiting on someone else, such as the network or
  /// the next driver, so it pulses. The pulse holds still under reduce
  /// motion.
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return Column(
      children: [
        for (final (i, s) in stages.indexed)
          Semantics(
            container: true,
            label: [
              switch (s.state) {
                StageState.done => l.lookStepDone,
                StageState.current => l.lookStepNow,
                StageState.upcoming => l.lookStepNext,
              },
              s.title,
              if (s.detail != null) s.detail!,
            ].join('. '),
            excludeSemantics: true,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 48,
                    child: Column(
                      children: [
                        _StageDot(
                          icon: s.icon,
                          state: s.state,
                          pulse: waiting && s.state == StageState.current,
                        ),
                        if (i < stages.length - 1)
                          Expanded(
                            child: Container(
                              width: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: s.state == StageState.done ? c.primary : c.outlineVariant,
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
                            s.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: s.state == StageState.upcoming
                                  ? c.onSurfaceVariant
                                  : c.onSurface,
                              fontWeight: s.state == StageState.current ? FontWeight.w800 : null,
                            ),
                          ),
                          if (s.detail != null)
                            Text(
                              s.detail!,
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
          ),
      ],
    );
  }
}

class _StageDot extends StatelessWidget {
  const _StageDot({required this.icon, required this.state, required this.pulse});

  final IconData icon;
  final StageState state;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final (bg, fg) = switch (state) {
      StageState.done => (c.primary, c.onPrimary),
      StageState.current => (c.primaryContainer, c.onPrimaryContainer),
      StageState.upcoming => (c.surfaceContainerHighest, c.onSurfaceVariant),
    };

    final dot = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: state == StageState.current ? Border.all(color: c.primary, width: 2) : null,
      ),
      child: Icon(state == StageState.done ? Icons.check : icon, size: 20, color: fg),
    );
    return SizedBox(
      width: 48,
      height: 48,
      child: pulse ? Pulse(color: c.primary, size: 48, rings: 1, child: dot) : Center(child: dot),
    );
  }
}
