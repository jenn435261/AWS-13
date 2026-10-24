import 'package:flutter/material.dart';

import '../../l10n/labels.dart';
import '../../models/role.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/theme.dart';

/// Optional sign-in. Anyone can ask for help as a guest; helpers, managers
/// and admins sign in.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _name = TextEditingController();
  Role _role = Role.client;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _signIn() {
    Haptics.success();
    AppScope.of(context).auth.signIn(name: _name.text, role: _role);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final auth = AppScope.of(context).auth;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.account)),
      body: ListenableBuilder(
        listenable: auth,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, helpButtonClearance + 16),
          children: auth.isSignedIn
              ? [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(l.signedInAs(auth.me.name)),
                    subtitle: Text(l.role(auth.role)),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      Haptics.tick();
                      auth.signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: Text(l.signOut),
                  ),
                ]
              : [
                  Text(l.signInSub, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _name,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _signIn(),
                    decoration: InputDecoration(
                      labelText: l.nameLabel,
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(l.roleLabel, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<Role>(
                    segments: [
                      for (final r in Role.values)
                        ButtonSegment(value: r, label: Text(l.role(r))),
                    ],
                    selected: {_role},
                    onSelectionChanged: (s) {
                      Haptics.tick();
                      setState(() => _role = s.first);
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _signIn,
                    icon: const Icon(Icons.login),
                    label: Text(l.signIn),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l.demoSignIn,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}
