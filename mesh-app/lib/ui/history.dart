import 'package:flutter/material.dart';

import '../l10n/labels.dart';
import '../models/event.dart';
import '../state/app_scope.dart';
import '../utils/format.dart';
import 'visuals.dart';

/// The signed events behind something, newest first (Spec sections 36 and
/// 37). Nothing here is ever edited; each later event refers back.
class SignedHistory extends StatelessWidget {
  const SignedHistory({super.key, required this.subject});

  /// The id of the request, mission or resource.
  final String subject;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return ValueListenableBuilder<List<SignedEvent>>(
      valueListenable: AppScope.of(context).repository.events,
      builder: (context, events, _) {
        final mine = [
          for (final e in events)
            if (e.subject == subject) e,
        ];
        if (mine.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(l.historyTitle, style: theme.textTheme.titleLarge),
            ),
            Text(l.historyHint, style: TextStyle(color: c.onSurfaceVariant)),
            for (final e in mine)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(eventIcon(e.type)),
                title: Text('${l.event(e.type)}  ·  ${clockTime(e.at)}'),
                subtitle: Text(
                  '${e.wireName}\n${l.signedBy(e.author.substring(0, 8))}  ·  '
                  '${e.signature.substring(0, 16)}',
                ),
              ),
          ],
        );
      },
    );
  }
}
