import 'package:flutter/material.dart';

import '../../data/mesh_repository.dart';
import '../../data/offline_map.dart';
import '../../l10n/labels.dart';
import '../../models/network.dart';
import '../../state/app_scope.dart';
import '../../ui/feedback.dart';
import '../../ui/surfaces.dart';
import '../../ui/theme.dart';
import '../map/street_map.dart';

/// What to download before an emergency (Spec section 35): the offline
/// street map, and the regional readiness package, from the cloud or from a
/// Resilience Node.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  void initState() {
    super.initState();
    // Quietly asks the Node whether it has a newer map.
    offlineMap.load().then((_) => offlineMap.checkForUpdate());
  }

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
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomClearance(context)),
        children: [
          const _OfflineMapCard(),
          const SizedBox(height: 12),
          ValueListenableBuilder<ReadinessPackage>(
            valueListenable: scope.repository.readiness,
            builder: (context, p, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 36),
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
          ),
        ],
      ),
    );
  }
}

/// The offline street map: its size on the phone, download progress, and
/// update and delete.
class _OfflineMapCard extends StatelessWidget {
  const _OfflineMapCard();

  Future<void> _download(BuildContext context) async {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    Haptics.tick();
    final before = offlineMap.info?.downloadedAt;
    await offlineMap.download();
    final after = offlineMap.info?.downloadedAt;
    if (after != null && after != before) {
      scope.feedback.toast(l.mapOfflineDone, icon: Icons.download_done);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    Haptics.tick();
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.mapOfflineDeleteTitle),
        content: Text(l.mapOfflineDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l.mapCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l.mapOfflineDelete),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await offlineMap.delete();
    scope.feedback.toast(l.mapOfflineDeleted, icon: Icons.delete_outline);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return ListenableBuilder(
      listenable: offlineMap,
      builder: (context, _) {
        final map = offlineMap;
        final info = map.info;
        final progress = map.progress;
        final problem = switch (map.problem) {
          null => null,
          OfflineMapProblem.unreachable => l.mapOfflineUnreachable,
          OfflineMapProblem.notFound => l.mapOfflineNotFound,
          OfflineMapProblem.notAMap => l.mapOfflineNotAMap,
          OfflineMapProblem.storage => l.mapOfflineStorage,
        };

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.map_outlined, size: 36),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l.mapOfflineTitle, style: theme.textTheme.titleLarge)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(l.mapOfflineAbout),
                const SizedBox(height: 16),
                if (map.downloading) ...[
                  LinearProgressIndicator(value: progress, minHeight: 8),
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      [
                        if (progress != null) l.downloadingPercent((progress * 100).round()),
                        if (map.totalBytes != null)
                          l.mapOfflineProgress(
                            megabytes(l, map.receivedBytes),
                            megabytes(l, map.totalBytes!),
                          )
                        else
                          megabytes(l, map.receivedBytes),
                      ].join('  ·  '),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Haptics.tick();
                      map.cancel();
                    },
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(l.mapOfflineCancel),
                  ),
                ] else if (info != null) ...[
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: c.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l.mapOfflineOnPhone(
                          megabytes(l, info.sizeBytes),
                          l.timeAgo(info.downloadedAt),
                        )),
                      ),
                    ],
                  ),
                  if (map.updateAvailable) ...[
                    const SizedBox(height: 8),
                    Text(l.mapOfflineNewer, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 12),
                  if (map.updateAvailable)
                    FilledButton.icon(
                      onPressed: () => _download(context),
                      icon: const Icon(Icons.download),
                      label: Text(l.mapOfflineUpdate),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => _download(context),
                      icon: const Icon(Icons.sync),
                      label: Text(l.mapOfflineUpdate),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: c.error),
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l.mapOfflineDelete),
                  ),
                ] else
                  MainButton(
                    label: l.mapOfflineDownload,
                    icon: Icons.download,
                    onPressed: () => _download(context),
                  ),
                if (problem != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, color: c.error),
                        const SizedBox(width: 8),
                        Expanded(child: Text(problem, style: TextStyle(color: c.error))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
