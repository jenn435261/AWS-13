import 'package:flutter/material.dart';

import '../../l10n/labels.dart';
import '../../models/app_user.dart';
import '../../models/role.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/theme.dart';

/// Admin only. Loaded as a deferred library, so on web, members and managers
/// never download this code.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.admin)),
      body: ValueListenableBuilder<List<AppUser>>(
        valueListenable: repo.users,
        builder: (context, users, _) => ListView(
          padding: const EdgeInsets.only(bottom: helpButtonClearance + 16),
          children: [
            for (final user in users)
              ListTile(
                leading: CircleAvatar(child: Text(user.name[0])),
                title: Text(user.name),
                trailing: DropdownButton<Role>(
                  value: user.role,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final r in Role.values)
                      DropdownMenuItem(value: r, child: Text(l.role(r))),
                  ],
                  onChanged: (r) {
                    if (r == null) return;
                    Haptics.tick();
                    repo.setUserRole(user.id, r);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
