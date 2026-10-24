import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/labels.dart';
import '../../models/help.dart';
import '../../router.dart';
import '../../state/app_scope.dart';
import '../../utils/emergency_call.dart';

/// Every action on a request, in one place, so the map, the lists and the
/// details screen all behave the same and every one can be undone.

Future<void> acceptRequest(BuildContext context, HelpRequest r) {
  final scope = AppScope.of(context);
  final l = AppLocalizations.of(context);
  return scope.undoable(
    context,
    message: l.acceptedToast,
    undone: l.releasedToast,
    icon: Icons.directions_run,
    run: () => scope.repository.acceptRequest(r.id, helper: scope.auth.me),
    revert: () => scope.repository.releaseRequest(r.id),
  );
}

Future<void> stopHelping(BuildContext context, HelpRequest r) {
  final scope = AppScope.of(context);
  final l = AppLocalizations.of(context);
  return scope.undoable(
    context,
    message: l.releasedToast,
    undone: l.acceptedToast,
    run: () => scope.repository.releaseRequest(r.id),
    revert: () => scope.repository.acceptRequest(r.id, helper: scope.auth.me),
  );
}

Future<void> cancelMyRequest(BuildContext context, HelpRequest r) {
  final scope = AppScope.of(context);
  final l = AppLocalizations.of(context);
  return scope.undoable(
    context,
    message: l.requestCancelled,
    undone: l.requestRestored,
    icon: Icons.cancel_outlined,
    run: () => scope.repository.cancelRequest(r.id),
    revert: () => scope.repository.restoreRequest(r),
  );
}

/// Quick actions for tap-and-hold on a request.
Future<void> showRequestActions(
  BuildContext context,
  HelpRequest r, {
  VoidCallback? onShowOnMap,
}) {
  final l = AppLocalizations.of(context);

  Widget action(BuildContext sheet, IconData icon, String label, VoidCallback run) =>
      ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: () {
          Navigator.pop(sheet);
          run();
        },
      );

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              l.requestTitle(r),
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            subtitle: Text(l.urgency(r.urgency)),
          ),
          if (!r.mine && r.isOpen)
            action(sheet, Icons.volunteer_activism, l.iCanHelp,
                () => acceptRequest(context, r)),
          if (r.helpingIsMe)
            action(sheet, Icons.cancel_outlined, l.stopHelping,
                () => stopHelping(context, r)),
          if (onShowOnMap != null)
            action(sheet, Icons.place_outlined, l.showOnMap, onShowOnMap),
          action(sheet, Icons.open_in_full, l.openDetails,
              () => context.go(requestPath(r.id))),
          if (r.mine)
            action(sheet, Icons.translate, l.showToResponder,
                () => context.push('${requestPath(r.id)}/card')),
          if (r.mine && r.stage != RequestStage.resolved)
            action(sheet, Icons.call, l.callEmergency,
                () => callEmergencyServices(context)),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
