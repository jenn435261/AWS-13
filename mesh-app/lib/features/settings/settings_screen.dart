import 'package:flutter/material.dart';

import '../../state/app_scope.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final user = scope.auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(user?.name ?? ''),
            subtitle: Text(user?.role.label ?? ''),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.contrast),
            title: const Text('Theme'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ListenableBuilder(
                listenable: scope.settings,
                builder: (context, _) => SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {scope.settings.themeMode},
                  onSelectionChanged: (s) => scope.settings.themeMode = s.first,
                ),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: scope.auth.signOut,
          ),
        ],
      ),
    );
  }
}
