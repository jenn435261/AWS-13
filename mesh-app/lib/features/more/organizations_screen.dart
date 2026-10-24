import 'package:flutter/material.dart';

import '../../l10n/labels.dart';
import '../../models/social.dart';
import '../../state/app_scope.dart';
import '../../ui/theme.dart';

/// The trust hierarchy this phone knows (Spec sections 54 and 55). Offline,
/// a phone only knows the revocations it has received, so freshness shows.
class OrganizationsScreen extends StatelessWidget {
  const OrganizationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l.orgsTitle)),
      body: ValueListenableBuilder<List<TrustedOrganization>>(
        valueListenable: AppScope.of(context).repository.organizations,
        builder: (context, orgs, _) {
          final byName = {for (final o in orgs) o.name: o};
          // How far below the root an organization sits, for indenting.
          int depth(TrustedOrganization o) {
            var d = 0;
            final seen = <String>{};
            for (var parent = byName[o.certifiedBy];
                parent != null && seen.add(parent.name);
                parent = byName[parent.certifiedBy]) {
              d++;
            }
            return d;
          }

          return ListView(
            padding: EdgeInsets.only(bottom: bottomClearance(context)),
            children: [
              if (orgs.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.history_toggle_off),
                  title: Text(l.revocationsChecked(l.timeAgo(orgs.first.checkedAt))),
                ),
              for (final o in orgs)
                Padding(
                  padding: EdgeInsets.only(left: 16.0 * depth(o)),
                  child: ListTile(
                    leading: Icon(Icons.verified, color: c.primary),
                    title: Text(o.name),
                    subtitle: Text(
                      '${o.category}  ·  '
                      '${o.certifiedBy == 'Root' ? l.rootOfTrust : l.certifiedBy(o.certifiedBy)}',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
