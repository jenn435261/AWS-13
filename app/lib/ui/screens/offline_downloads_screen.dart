import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../l10n/strings.dart';
import '../components/common.dart';
import '../theme/app_theme.dart';

/// Offline packages come from a Resilience Node on the local Wi-Fi (Android
/// app, offline map, readiness guide). This screen probes the node you point it
/// at and shows what it really serves, with a copyable link for each package.
/// It never claims a download exists that the node did not confirm.
class OfflineDownloadsScreen extends ConsumerStatefulWidget {
  const OfflineDownloadsScreen({super.key});

  @override
  ConsumerState<OfflineDownloadsScreen> createState() => _State();
}

enum _Probe { idle, checking, ok, missing, unreachable }

class _Pkg {
  final String labelKey;
  final IconData icon;
  final String path;
  _Probe state = _Probe.idle;
  _Pkg(this.labelKey, this.icon, this.path);
}

class _State extends ConsumerState<OfflineDownloadsScreen> {
  final _address = TextEditingController();
  final _pkgs = <_Pkg>[
    _Pkg('pkg_app', Icons.android_rounded, '/node/v1/apk'),
    _Pkg('pkg_map', Icons.map_outlined, '/node/v1/map/region.pmtiles'),
    _Pkg('pkg_readiness', Icons.menu_book_outlined, '/node/v1/readiness/guide'),
  ];
  bool _checked = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  String get _base => _address.text.trim().replaceAll(RegExp(r'/+$'), '');

  Future<void> _check() async {
    if (_base.isEmpty) return;
    setState(() {
      _checked = true;
      for (final p in _pkgs) {
        p.state = _Probe.checking;
      }
    });
    for (final p in _pkgs) {
      _Probe result;
      try {
        final r = await http
            .head(Uri.parse('$_base${p.path}'))
            .timeout(const Duration(seconds: 5));
        result = r.statusCode >= 200 && r.statusCode < 300
            ? _Probe.ok
            : _Probe.missing;
      } catch (_) {
        result = _Probe.unreachable;
      }
      if (!mounted) return;
      setState(() => p.state = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final outline = Theme.of(context).colorScheme.outline;
    return Scaffold(
      appBar: AppBar(title: Text(l.t('offline_downloads'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.t('downloads_explainer'),
                style: TextStyle(
                    fontFamily: 'Roboto', fontSize: 16, color: outline)),
            const SizedBox(height: 16),
            TextField(
              controller: _address,
              keyboardType: TextInputType.url,
              style: const TextStyle(fontFamily: 'Roboto', fontSize: 16),
              decoration: InputDecoration(
                labelText: l.t('node_address'),
                hintText: l.t('node_hint'),
              ),
              onSubmitted: (_) => _check(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _check,
              icon: const Icon(Icons.network_check_rounded),
              label: Text(l.t('check_node')),
            ),
            const SizedBox(height: 16),
            if (!_checked)
              Text(l.t('node_not_set'),
                  style: TextStyle(
                      fontFamily: 'Roboto', fontSize: 16, color: outline))
            else
              for (final p in _pkgs) _tile(context, l, p),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, L10n l, _Pkg p) {
    final scheme = Theme.of(context).colorScheme;
    final (String text, Color color) = switch (p.state) {
      _Probe.ok => (l.t('pkg_available'), AppTheme.verified),
      _Probe.missing => (l.t('pkg_missing'), scheme.outline),
      _Probe.unreachable => (l.t('pkg_unreachable'), scheme.error),
      _ => (l.t('status_checking'), scheme.outline),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(p.icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l.t(p.labelKey),
                    style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              Text(text,
                  style: TextStyle(
                      fontFamily: 'Roboto', fontSize: 16, color: color)),
            ]),
            if (p.state == _Probe.ok) ...[
              const SizedBox(height: 8),
              CopyableText(
                  value: '$_base${p.path}', copiedMessage: l.t('copied')),
            ],
          ],
        ),
      ),
    );
  }
}
