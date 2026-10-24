import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../theme/app_theme.dart';

/// Result of probing the cloud API's /healthz.
class CloudProbe {
  final bool reachable;
  final int? latencyMs;
  final DateTime checkedAt;
  const CloudProbe(this.reachable, this.latencyMs, this.checkedAt);
}

/// Bumped by the Refresh button to re-run [cloudProbeProvider].
final cloudProbeRevisionProvider = StateProvider<int>((ref) => 0);

/// Actually asks the cloud whether it is up. Empty base URL => not configured
/// (returns null). This is what "Internet" means here: the app can reach its
/// backend, not merely that the phone has a network.
final cloudProbeProvider = FutureProvider.autoDispose<CloudProbe?>((ref) async {
  ref.watch(cloudProbeRevisionProvider);
  final base = ref.watch(cloudBaseUrlProvider).replaceAll(RegExp(r'/+$'), '');
  if (base.isEmpty) return null;
  final sw = Stopwatch()..start();
  try {
    final r = await http
        .get(Uri.parse('$base/healthz'))
        .timeout(const Duration(seconds: 5));
    return CloudProbe(
        r.statusCode == 200, sw.elapsedMilliseconds, DateTime.now());
  } catch (_) {
    return CloudProbe(false, null, DateTime.now());
  }
});

/// Network status made understandable (spec §65). Each row reports something
/// the app actually measured or knows; transports that do not exist on this
/// platform or are not set up say so instead of showing a fake "off" state.
class NetworkStatusScreen extends ConsumerWidget {
  const NetworkStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final probe = ref.watch(cloudProbeProvider);

    final _Row internet = probe.when(
      loading: () => _Row(l.t('status_checking'), _Tone.neutral),
      error: (e, _) => _Row(l.t('status_unreachable'), _Tone.bad),
      data: (p) {
        if (p == null) return _Row(l.t('status_not_configured'), _Tone.neutral);
        return p.reachable
            ? _Row('${l.t('status_reachable')} · ${p.latencyMs} ms', _Tone.good)
            : _Row(l.t('status_unreachable'), _Tone.bad);
      },
    );
    final checkedAt = probe.valueOrNull?.checkedAt;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('network_status')),
        actions: [
          IconButton(
            tooltip: l.t('refresh'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(cloudProbeRevisionProvider.notifier).state++,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          children: [
            _row(context, Icons.public_rounded, l.t('conn_internet'), internet),
            _row(
                context,
                Icons.wifi_tethering_rounded,
                l.t('nearby_peers'),
                _Row(
                    kIsWeb
                        ? l.t('status_unavailable_here')
                        : l.t('status_not_configured'),
                    _Tone.neutral)),
            _row(context, Icons.router_rounded, l.t('resilience_node'),
                _Row(l.t('status_not_configured'), _Tone.neutral)),
            _row(context, Icons.cell_tower_rounded, l.t('lora'),
                _Row(l.t('status_not_supported'), _Tone.neutral)),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.sync_rounded),
              title: Text(l.t('last_checked'),
                  style:
                      const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
              trailing: Text(
                checkedAt == null ? '—' : _clock(checkedAt),
                style: const TextStyle(fontFamily: 'Roboto', fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  Widget _row(BuildContext context, IconData icon, String label, _Row r) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (r.tone) {
      _Tone.good => AppTheme.verified,
      _Tone.bad => scheme.error,
      _Tone.neutral => scheme.outline,
    };
    return ListTile(
      leading: Icon(icon),
      title: Text(label,
          style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
      subtitle: Text(r.text,
          style: TextStyle(fontFamily: 'Roboto', fontSize: 16, color: color)),
      trailing: Icon(
        switch (r.tone) {
          _Tone.good => Icons.check_circle_rounded,
          _Tone.bad => Icons.error_rounded,
          _Tone.neutral => Icons.remove_circle_outline_rounded,
        },
        color: color,
      ),
    );
  }
}

enum _Tone { good, bad, neutral }

class _Row {
  final String text;
  final _Tone tone;
  _Row(this.text, this.tone);
}
