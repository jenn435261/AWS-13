import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../../nodes/node_store.dart';
import '../../sync/sync_providers.dart';
import '../../transport/transport_status.dart';
import '../theme/app_theme.dart';
import 'nodes_screen.dart';
import 'qr_transfer_screen.dart';

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

    final nodes = ref.watch(nodesProvider).valueOrNull ?? const <SavedNode>[];
    final activeId = ref.watch(activeNodeIdProvider).valueOrNull;
    final SavedNode? node = nodes.isEmpty
        ? null
        : nodes.firstWhere((n) => n.id == activeId, orElse: () => nodes.first);
    _Row nodeRow = _Row(l.t('status_not_configured'), _Tone.neutral);
    if (node != null) {
      final np = ref.watch(nodeProbeProvider(node.url));
      nodeRow = np.when(
        loading: () => _Row('${node.name} · ${l.t('status_checking')}', _Tone.neutral),
        error: (e, _) => _Row('${node.name} · ${l.t('status_unreachable')}', _Tone.bad),
        data: (p) => p.reachable
            ? _Row('${node.name} · ${l.t('status_reachable')} · ${p.latencyMs} ms', _Tone.good)
            : _Row('${node.name} · ${l.t('status_unreachable')}', _Tone.bad),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('network_status')),
        actions: [
          IconButton(
            tooltip: l.t('refresh'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(cloudProbeRevisionProvider.notifier).state++;
              ref.read(nodesRevisionProvider.notifier).state++;
              ref.read(syncCoordinatorProvider).syncNow();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          children: [
            // Cloud + Node are driven by live probes.
            _row(context, Icons.public_rounded, l.t('transport_cloud'),
                internet),
            InkWell(
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NodesScreen())),
              child: _row(context, Icons.router_rounded, l.t('transport_node'),
                  nodeRow),
            ),
            // Radio + QR transports: honest state, never a fake "connected".
            // In this build no live BLE/LoRa/Nearby session is wired into the
            // provider graph yet, so they report their honest resting state
            // (unavailable on web; needs real devices/hardware on native).
            ..._radioRows(context, l),
            const Divider(),
            _syncTile(context, ref, l),
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

  /// The honest radio + QR transport rows (Nearby, BLE, LoRa, QR).
  List<Widget> _radioRows(BuildContext context, L10n l) {
    final rows = radioTransportRows();
    return rows.map((s) {
      final icon = switch (s.labelKey) {
        'transport_nearby' => Icons.wifi_tethering_rounded,
        'transport_ble' => Icons.bluetooth_rounded,
        'transport_lora' => Icons.cell_tower_rounded,
        'transport_qr' => Icons.qr_code_2_rounded,
        _ => Icons.hub_rounded,
      };
      final tone = switch (s.tone) {
        StatusTone.good => _Tone.good,
        StatusTone.bad => _Tone.bad,
        StatusTone.neutral => _Tone.neutral,
      };
      String text = l.t(s.stateKey);
      if (s.lastActivityMs != null) {
        text = '$text · ${l.t('status_last_activity').replaceFirst('{time}', _clock(DateTime.fromMillisecondsSinceEpoch(s.lastActivityMs!)))}';
      }
      final row = _row(context, icon, l.t(s.labelKey), _Row(text, tone));
      // QR transfer is actionable: tapping it opens the Transfer-by-QR screen.
      if (s.labelKey == 'transport_qr') {
        return InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const QrTransferScreen())),
          child: row,
        );
      }
      return row;
    }).toList();
  }

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  /// The real sync row: "Last synced (relative) · N pending" with the last
  /// error shown truthfully when the most recent round failed. Driven entirely
  /// by live [SyncStatus].
  Widget _syncTile(BuildContext context, WidgetRef ref, L10n l) {
    final status = ref.watch(syncStatusProvider);
    final scheme = Theme.of(context).colorScheme;

    final parts = <String>[];
    if (status.lastSyncedMs == null) {
      parts.add(l.t('sync_never'));
    } else {
      parts.add('${l.t('last_synced')} ${_relative(status.lastSyncedMs!, l)}');
    }
    parts.add(l.t('sync_pending').replaceFirst('{n}', '${status.pendingCount}'));
    final summary = parts.join(' · ');

    final hasError = status.lastError != null;
    final color = hasError
        ? scheme.error
        : (status.pendingCount > 0 ? scheme.outline : AppTheme.verified);

    return ListTile(
      leading: status.syncing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : const Icon(Icons.cloud_sync_rounded),
      title: Text(l.t('sync_status'),
          style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary,
              style: TextStyle(
                  fontFamily: 'Roboto', fontSize: 16, color: color)),
          if (hasError)
            Text('${l.t('sync_error')}: ${status.lastError}',
                style: TextStyle(
                    fontFamily: 'Roboto', fontSize: 16, color: scheme.error)),
        ],
      ),
    );
  }

  /// A short, locale-neutral relative time ("just now", "5m ago", "2h ago").
  static String _relative(int ms, L10n l) {
    final diff = DateTime.now().millisecondsSinceEpoch - ms;
    if (diff < 60 * 1000) return l.t('time_just_now');
    if (diff < 60 * 60 * 1000) {
      return l.t('time_minutes_ago').replaceFirst('{n}', '${diff ~/ 60000}');
    }
    if (diff < 24 * 60 * 60 * 1000) {
      return l.t('time_hours_ago').replaceFirst('{n}', '${diff ~/ 3600000}');
    }
    return l.t('time_days_ago').replaceFirst('{n}', '${diff ~/ 86400000}');
  }

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
