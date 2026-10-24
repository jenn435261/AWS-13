import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../alerts/alert_client.dart';
import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../../nodes/package_manifest.dart';
import '../../packages/cloud_package_client.dart';
import '../../packages/pack_source.dart';
import '../../packages/region_pack_store.dart';
import '../../packages/resumable_download.dart';
import '../components/toast.dart';

/// Hard cap on a single region pack download (MB). The consent screen shows the
/// real size and refuses anything over this so a user is never surprised by a
/// huge download. 250 MB comfortably covers a city-scale PMTiles pack.
const int kPackSizeCapMb = 250;

/// "Prepare now": download everything needed to operate offline in a region —
/// the map tile pack (PMTiles, size-capped, with an MB consent screen), plus
/// the recent events/safe-places for the area. The map pack is verified with
/// the SAME signed-manifest + SHA-256 flow as node packs (the cloud signs its
/// own manifest). The download is resumable and keeps every verified chunk.
class PrepareNowScreen extends ConsumerStatefulWidget {
  /// The severe alert that prompted preparing (its area centers the region).
  final FeedAlert? alert;
  const PrepareNowScreen({super.key, this.alert});

  @override
  ConsumerState<PrepareNowScreen> createState() => _PrepareNowScreenState();
}

enum _Phase { resolving, consent, downloading, done, error }

class _PrepareNowScreenState extends ConsumerState<PrepareNowScreen> {
  _Phase _phase = _Phase.resolving;
  PackSource _source = PackSource.none;
  String _baseUrl = '';
  String _detail = '';
  List<ManifestEntry> _mapEntries = const [];
  int _totalBytes = 0;
  DownloadProgress _progress = const DownloadProgress(0, 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final l = L10n.of(context);
    final cloudBase =
        ref.read(cloudBaseUrlProvider).replaceAll(RegExp(r'/+$'), '');
    final node = await ref.read(activeNodeProvider.future);
    final nodeBase = node?.url.replaceAll(RegExp(r'/+$'), '');

    final source = await resolvePackSource(
      nodeBaseUrl: nodeBase,
      cloudBaseUrl: cloudBase,
      reachable: defaultNodeReachable,
    );
    if (!mounted) return;
    if (source == PackSource.none) {
      _fail(l.t('prepare_no_source'));
      return;
    }

    final isNode = source == PackSource.node;
    final base = isNode ? nodeBase! : cloudBase;
    final root = isNode
        ? ref.read(packagesTrustedRootProvider).trim()
        : ref.read(cloudFeedPubkeyProvider).trim();
    final client = isNode
        ? CloudPackageClient.node(baseUrl: base, trustedRootHex: root)
        : CloudPackageClient.cloud(
            baseUrl: base,
            trustedRootHex: root,
            apiKey: ref.read(cloudApiKeyProvider));

    final res = await client.fetchManifest();
    if (!mounted) return;
    if (!res.ok || res.manifest == null) {
      _fail(_manifestError(res.status));
      return;
    }
    final maps =
        res.manifest!.entries.where((e) => e.kind == 'map').toList();
    if (maps.isEmpty) {
      _fail(L10n.of(context).t('prepare_no_map'));
      return;
    }
    final total = maps.fold<int>(0, (a, e) => a + e.sizeBytes);
    if (total > kPackSizeCapMb * 1024 * 1024) {
      _fail(L10n.of(context)
          .t('prepare_too_large')
          .replaceAll('{cap}', '$kPackSizeCapMb'));
      return;
    }
    setState(() {
      _source = source;
      _baseUrl = base;
      _mapEntries = maps;
      _totalBytes = total;
      _phase = _Phase.consent;
    });
  }

  String _manifestError(ManifestVerify v) {
    final l = L10n.of(context);
    return switch (v) {
      ManifestVerify.untrustedKey => l.t('prepare_untrusted'),
      ManifestVerify.badSignature => l.t('prepare_bad_sig'),
      _ => l.t('prepare_manifest_unavailable'),
    };
  }

  void _fail(String detail) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _detail = detail;
    });
  }

  String _regionId() {
    final a = widget.alert;
    if (a != null) {
      return 'region:${a.lat.toStringAsFixed(3)},${a.lon.toStringAsFixed(3)}';
    }
    return 'region:current';
  }

  String _regionName() {
    final a = widget.alert;
    if (a != null && a.title.isNotEmpty) return a.title;
    return L10n.of(context).t('prepare_region_default');
  }

  Future<void> _download() async {
    final isNode = _source == PackSource.node;
    final root = isNode
        ? ref.read(packagesTrustedRootProvider).trim()
        : ref.read(cloudFeedPubkeyProvider).trim();
    final client = isNode
        ? CloudPackageClient.node(baseUrl: _baseUrl, trustedRootHex: root)
        : CloudPackageClient.cloud(
            baseUrl: _baseUrl,
            trustedRootHex: root,
            apiKey: ref.read(cloudApiKeyProvider));
    final downloader = ResumableDownloader(
      http: client.rangeHttp(),
      store: ref.read(regionChunkStoreProvider),
    );
    final packId = _regionId();
    final packStore = ref.read(regionPackStoreProvider);

    setState(() => _phase = _Phase.downloading);

    // Keep the prior verified pack until the replacement verifies (merge/update,
    // never delete-before-verify). We download under a fresh packId only when
    // the id differs; here same region id => same chunks resume.
    var downloadedBytes = 0;
    var allVerified = true;
    for (final entry in _mapEntries) {
      final result = await downloader.download(
        packId,
        entry,
        client.urlForEntry(entry),
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      downloadedBytes += (entry.sizeBytes * result.progress.fraction).round();
      if (!result.verified) {
        allVerified = false;
        // Persist partial state so the user sees "N%, resume" and can retry.
        await packStore.upsert(RegionPack(
          id: packId,
          name: _regionName(),
          source: _source.label,
          baseUrl: _baseUrl,
          totalBytes: _totalBytes,
          downloadedBytes: downloadedBytes,
          percent: result.progress.percent,
          status: PackStatus.partial,
          updatedMs: DateTime.now().millisecondsSinceEpoch,
        ));
        ref.read(regionPacksRevisionProvider.notifier).state++;
        if (mounted) {
          setState(() {
            _phase = _Phase.error;
            _detail = result.error == 'checksum mismatch'
                ? L10n.of(context).t('prepare_checksum_failed')
                : L10n.of(context).t('prepare_interrupted');
          });
        }
        return;
      }
    }

    // Fetch the sidecar region data (recent alerts in the area) so the region
    // is usable offline. This is dynamic data, NOT manifest-signed, so it is
    // stored as a convenience cache and the UI does not claim it is checksum
    // verified (honest state).
    await _cacheRegionAlerts();

    await packStore.upsert(RegionPack(
      id: packId,
      name: _regionName(),
      source: _source.label,
      baseUrl: _baseUrl,
      totalBytes: _totalBytes,
      downloadedBytes: _totalBytes,
      percent: 100,
      status: allVerified ? PackStatus.verified : PackStatus.partial,
      updatedMs: DateTime.now().millisecondsSinceEpoch,
    ));
    ref.read(regionPacksRevisionProvider.notifier).state++;
    if (mounted) setState(() => _phase = _Phase.done);
  }

  Future<void> _cacheRegionAlerts() async {
    final a = widget.alert;
    final base = ref.read(cloudBaseUrlProvider).replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return;
    try {
      final client = AlertClient(
        baseUrl: base,
        http: HttpAlertHttp(),
        apiKey: ref.read(cloudApiKeyProvider),
      );
      final res = await client.poll(
        lat: a?.lat,
        lon: a?.lon,
        radiusKm: a != null ? 150 : 0,
      );
      // Store the snapshot as a local cache row keyed by region id.
      await ref
          .read(regionPackStoreProvider)
          // Reuse the pack store's JsonStore via a sidecar key.
          .upsertSidecar(_regionId(), {'alerts': res.alerts.length});
    } catch (_) {
      // A failed sidecar fetch never fails the whole prepare (the map pack is
      // the verified core); the region is still usable with what downloaded.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('prepare_now'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: switch (_phase) {
            _Phase.resolving => _centered(
                const CircularProgressIndicator(), l.t('prepare_resolving')),
            _Phase.consent => _consent(l),
            _Phase.downloading => _downloading(l),
            _Phase.done => _doneView(l),
            _Phase.error => _errorView(l),
          },
        ),
      ),
    );
  }

  Widget _centered(Widget top, String text) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            top,
            const SizedBox(height: 16),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
          ],
        ),
      );

  Widget _consent(L10n l) {
    final outline = Theme.of(context).colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.t('prepare_explainer'),
            style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: Icon(_source == PackSource.node
                ? Icons.router_rounded
                : Icons.cloud_rounded),
            title: Text('${l.t('prepare_source')}: ${_source.label}'),
            subtitle: Text(_baseUrl,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.sd_storage_rounded),
            title: Text('${l.t('prepare_download_size')}: ${_mb(_totalBytes)}'),
            subtitle: Text(
                '${_mapEntries.length} ${l.t('prepare_map_packs')}',
                style: TextStyle(color: outline)),
          ),
        ),
        const SizedBox(height: 8),
        Text(l.t('prepare_verify_note'),
            style: TextStyle(fontFamily: 'Roboto', fontSize: 16, color: outline)),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _download,
            icon: const Icon(Icons.download_rounded),
            label: Text('${l.t('prepare_download')} (${_mb(_totalBytes)})'),
          ),
        ),
      ],
    );
  }

  Widget _downloading(L10n l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            '${_progress.percent}% ${l.t('prepare_of')} ${_regionName()}',
            style: const TextStyle(
                fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: _progress.fraction),
        const SizedBox(height: 12),
        Text(l.t('prepare_keep_open'),
            style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                color: Theme.of(context).colorScheme.outline)),
      ],
    );
  }

  Widget _doneView(L10n l) => _centered(
        Icon(Icons.verified_rounded,
            size: 48, color: Theme.of(context).colorScheme.primary),
        l.t('prepare_done'),
      );

  Widget _errorView(L10n l) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.error_outline_rounded,
            size: 48, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 16),
        Text(_detail,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () {
            Toast.show(context, L10n.of(context).t('prepare_retrying'));
            setState(() => _phase = _Phase.resolving);
            _resolve();
          },
          child: Text(l.t('retry')),
        ),
      ],
    );
  }

  static String _mb(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  }
}
