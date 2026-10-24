import 'package:flutter/material.dart';

import '../../l10n/labels.dart';
import '../../models/app_user.dart';
import '../../models/role.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/surfaces.dart';
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
          padding: EdgeInsets.only(bottom: bottomClearance(context)),
          children: [
            for (final user in users)
              // The role sits under the name, so long role names and large
              // text never squeeze the name out.
              ListTile(
                leading: Avatar(name: user.name),
                title: Text(user.name),
                subtitle: DropdownButton<Role>(
                  value: user.role,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final r in Role.values)
                      DropdownMenuItem(
                        value: r,
                        child: Text(l.role(r), overflow: TextOverflow.ellipsis),
                      ),
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
