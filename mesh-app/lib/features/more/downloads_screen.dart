import 'package:flutter/material.dart';

import '../../data/mesh_repository.dart';
import '../../l10n/labels.dart';
import '../../models/network.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/theme.dart';

/// The regional readiness package, downloaded before an emergency, from the
/// cloud or from a Resilience Node (Spec section 35).
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  Future<void> _download(BuildContext context) async {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    Haptics.tick();
    try {
      await scope.repository.downloadReadiness();
    } on NeedsInternet {
      scope.feedback.toast(l.downloadNeedsNet, icon: Icons.cloud_off);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.downloadsTitle)),
      body: ValueListenableBuilder<ReadinessPackage>(
        valueListenable: scope.repository.readiness,
        builder: (context, p, _) {
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomClearance(context)),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.map_outlined, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(l.packageTitle(p.region), style: theme.textTheme.titleLarge),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(l.packageSize(p.sizeMb, p.version)),
                      const SizedBox(height: 8),
                      Text(l.packageContents),
                      const SizedBox(height: 16),
                      if (p.downloading) ...[
                        LinearProgressIndicator(value: p.progress, minHeight: 8),
                        const SizedBox(height: 8),
                        Semantics(
                          liveRegion: true,
                          child: Text(l.downloadingPercent(((p.progress ?? 0) * 100).round())),
                        ),
                      ] else if (p.updateAvailable) ...[
                        Text(l.packageUpdate(p.version), style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _download(context),
                          icon: const Icon(Icons.download),
                          label: Text(l.downloadNow),
                        ),
                      ] else
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(l.packageUpToDate(l.timeAgo(p.downloadedAt!)))),
                          ],
                        ),
                    ],
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
