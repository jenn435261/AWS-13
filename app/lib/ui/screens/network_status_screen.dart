import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../theme/app_theme.dart';

/// Network status made understandable (spec §65): shows each transport's state
/// without networking jargon. Internet / nearby peers / node / LoRa + last
/// sync age.
class NetworkStatusScreen extends ConsumerWidget {
  const NetworkStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final online = ref.watch(cloudBaseUrlProvider).isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('network_status'))),
      body: SafeArea(
        child: ListView(
          children: [
            _row(context, Icons.public_rounded, l.t('conn_internet'),
                ok: online),
            _row(context, Icons.wifi_tethering_rounded, l.t('nearby_peers'),
                ok: false, trailing: '0'),
            _row(context, Icons.router_rounded, l.t('resilience_node'),
                ok: false),
            _row(context, Icons.cell_tower_rounded, l.t('lora'), ok: false),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.sync_rounded),
              title: Text(l.t('last_sync')),
              trailing:
                  const Text('—', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label,
      {required bool ok, String? trailing}) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
      trailing: trailing != null
          ? Text(trailing, style: const TextStyle(fontFamily: 'Roboto', fontSize: 16))
          : Icon(
              ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: ok ? AppTheme.verified : scheme.outline,
            ),
    );
  }
}
