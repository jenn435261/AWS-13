import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../../nodes/node_store.dart';
import '../../nodes/package_manifest.dart';
import '../../nodes/package_store.dart';
import '../../packages/pack_source.dart';
import '../components/common.dart';
import '../components/toast.dart';
import 'nodes_screen.dart';
import 'storage_screen.dart';

/// One item a node reports in its /node/v1/packages catalog.
class _CatalogItem {
  final String kind;
  final String name;
  final String path;
  final int sizeBytes;
  final int modifiedMs;
  _CatalogItem(this.kind, this.name, this.path, this.sizeBytes, this.modifiedMs);
}

PackageKind _kindOf(String k) => switch (k) {
      'app' => PackageKind.app,
      'map' => PackageKind.map,
      'readiness' => PackageKind.readiness,
      _ => PackageKind.other,
    };

IconData _iconOf(PackageKind k) => switch (k) {
      PackageKind.app => Icons.android_rounded,
      PackageKind.map => Icons.map_outlined,
      PackageKind.readiness => Icons.menu_book_outlined,
      PackageKind.other => Icons.insert_drive_file_outlined,
    };

String _size(int bytes) {
  if (bytes <= 0) return '';
  const u = ['B', 'KB', 'MB', 'GB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${u[i]}';
}

String _date(int ms) {
  if (ms <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Offline Downloads: pick one of your saved nodes, see exactly what it serves
/// (from its own catalog, never guessed), and keep your own library of package
/// versions that you can add, edit, check, open and delete.
class OfflineDownloadsScreen extends ConsumerStatefulWidget {
  /// Node to preselect (from the Saved nodes screen).
  final String? nodeId;
  const OfflineDownloadsScreen({super.key, this.nodeId});

  @override
  ConsumerState<OfflineDownloadsScreen> createState() => _State();
}

enum _Load { idle, loading, ok, unreachable }

/// Trust state of the node's signed package manifest.
enum _Manifest {
  /// Not fetched yet (node not checked).
  none,

  /// The node does not serve a signed manifest.
  unavailable,

  /// A manifest was served but could not be trusted (no trusted root
  /// configured, wrong signer, or bad signature).
  untrusted,

  /// The manifest verified against the configured trusted root.
  verified,
}

class _State extends ConsumerState<OfflineDownloadsScreen> {
  String? _nodeId;
  _Load _load = _Load.idle;
  List<_CatalogItem> _catalog = const [];
  _Manifest _manifestState = _Manifest.none;
  PackageManifest? _manifest;

  /// The resolved preferred source (node on LAN else cloud), shown so the user
  /// always knows which is in use. Resolved honestly by probing reachability.
  PackSource _preferredSource = PackSource.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveSource());
  }

  Future<void> _resolveSource() async {
    final cloudBase =
        ref.read(cloudBaseUrlProvider).replaceAll(RegExp(r'/+$'), '');
    final node = await ref.read(activeNodeProvider.future);
    final src = await resolvePackSource(
      nodeBaseUrl: node?.url,
      cloudBaseUrl: cloudBase,
      reachable: defaultNodeReachable,
    );
    if (mounted) setState(() => _preferredSource = src);
  }

  SavedNode? _selected(List<SavedNode> nodes, String? active) {
    if (nodes.isEmpty) return null;
    final id = _nodeId ?? widget.nodeId ?? active;
    return nodes.firstWhere((n) => n.id == id, orElse: () => nodes.first);
  }

  Future<void> _fetch(SavedNode node) async {
    setState(() {
      _load = _Load.loading;
      _catalog = const [];
      _manifestState = _Manifest.none;
      _manifest = null;
    });
    try {
      final r = await http
          .get(Uri.parse('${node.url}/node/v1/packages'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) throw Exception('status ${r.statusCode}');
      final items = (jsonDecode(r.body)['items'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((j) => _CatalogItem(
              j['kind'] as String? ?? 'other',
              j['name'] as String? ?? '',
              j['path'] as String? ?? '',
              (j['size_bytes'] as num?)?.toInt() ?? 0,
              (j['modified_ms'] as num?)?.toInt() ?? 0))
          .where((i) => i.name.isNotEmpty && i.path.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _catalog = items;
        _load = _Load.ok;
      });
      await _fetchManifest(node);
    } catch (_) {
      if (mounted) setState(() => _load = _Load.unreachable);
    }
  }

  /// Fetches and verifies the node's signed package manifest. The manifest's
  /// trust state is advisory for the UI; a download is only ever trusted when
  /// its SHA-256 matches a VERIFIED manifest entry (see [_check]).
  Future<void> _fetchManifest(SavedNode node) async {
    final root = ref.read(packagesTrustedRootProvider).trim();
    try {
      final r = await http
          .get(Uri.parse('${node.url}/node/v1/manifest'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) {
        if (mounted) setState(() => _manifestState = _Manifest.unavailable);
        return;
      }
      final body = jsonDecode(r.body);
      if (body is! Map<String, dynamic>) {
        if (mounted) setState(() => _manifestState = _Manifest.untrusted);
        return;
      }
      if (root.isEmpty) {
        // No trusted root configured for this build: we received a manifest but
        // cannot trust it, so we must not claim verification.
        if (mounted) setState(() => _manifestState = _Manifest.untrusted);
        return;
      }
      final res = await verifySignedManifest(body, root);
      if (!mounted) return;
      setState(() {
        if (res.ok) {
          _manifest = res.manifest;
          _manifestState = _Manifest.verified;
        } else {
          _manifestState = _Manifest.untrusted;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _manifestState = _Manifest.unavailable);
    }
  }

  Future<void> _open(String url) async {
    final l = L10n.of(context);
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) Toast.show(context, l.t('cannot_open_link'), urgent: true);
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) Toast.show(context, L10n.of(context).t('copied'));
  }

  Future<void> _saveToLibrary(SavedNode node, _CatalogItem it) async {
    final l = L10n.of(context);
    final p = await showDialog<SavedPackage>(
        context: context,
        builder: (_) => _PackageDialog(
            initial: SavedPackage(
                id: '',
                kind: _kindOf(it.kind),
                name: it.name,
                version: _date(it.modifiedMs),
                url: '${node.url}${it.path}',
                sizeBytes: it.sizeBytes,
                addedMs: 0)));
    if (p == null) return;
    await ref.read(packageStoreProvider).add(
        kind: p.kind,
        name: p.name,
        version: p.version,
        url: p.url,
        notes: p.notes,
        sizeBytes: it.sizeBytes);
    ref.read(packagesRevisionProvider.notifier).state++;
    if (mounted) Toast.show(context, l.t('package_saved'));
  }

  Future<void> _addManual() async {
    final l = L10n.of(context);
    final p = await showDialog<SavedPackage>(
        context: context,
        builder: (_) => _PackageDialog(
            initial: SavedPackage(
                id: '',
                kind: PackageKind.other,
                name: '',
                version: '',
                url: '',
                addedMs: 0)));
    if (p == null) return;
    await ref.read(packageStoreProvider).add(
        kind: p.kind, name: p.name, version: p.version, url: p.url, notes: p.notes);
    ref.read(packagesRevisionProvider.notifier).state++;
    if (mounted) Toast.show(context, l.t('package_saved'));
  }

  Future<void> _edit(SavedPackage pkg) async {
    final l = L10n.of(context);
    final p = await showDialog<SavedPackage>(
        context: context, builder: (_) => _PackageDialog(initial: pkg));
    if (p == null) return;
    await ref.read(packageStoreProvider).update(pkg.copyWith(
        kind: p.kind, name: p.name, version: p.version, url: p.url, notes: p.notes));
    ref.read(packagesRevisionProvider.notifier).state++;
    if (mounted) Toast.show(context, l.t('package_updated'));
  }

  Future<void> _delete(SavedPackage pkg) async {
    final l = L10n.of(context);
    final store = ref.read(packageStoreProvider);
    await store.remove(pkg.id);
    ref.read(packagesRevisionProvider.notifier).state++;
    if (!mounted) return;
    Toast.show(context, l.t('package_removed'),
        undoLabel: l.t('undo'), onUndo: () async {
      await store.update(pkg);
      ref.read(packagesRevisionProvider.notifier).state++;
    });
  }

  Future<void> _check(SavedPackage pkg) async {
    final l = L10n.of(context);
    // When a verified manifest covers this URL, verify the actual bytes against
    // its checksum rather than just checking that the file exists.
    final entry = _manifestEntryForUrl(pkg.url);
    if (entry != null) {
      await _verifyChecksum(pkg.url, entry, '${pkg.name} ${pkg.version}');
      return;
    }
    String msg;
    try {
      final r = await http
          .head(Uri.parse(pkg.url))
          .timeout(const Duration(seconds: 5));
      msg = r.statusCode >= 200 && r.statusCode < 300
          ? l.t('pkg_available')
          : l.t('pkg_missing');
    } catch (_) {
      msg = l.t('pkg_unreachable');
    }
    if (mounted) Toast.show(context, '${pkg.name} ${pkg.version}: $msg');
  }

  /// Returns the verified manifest entry whose path matches [url] (a full
  /// `${node.url}${path}` URL), or null when no verified manifest covers it.
  ManifestEntry? _manifestEntryForUrl(String url) {
    final m = _manifest;
    if (m == null || _manifestState != _Manifest.verified) return null;
    final path = Uri.tryParse(url)?.path;
    if (path == null) return null;
    return m.entryForPath(path);
  }

  /// Downloads [url] and verifies its SHA-256 against the verified manifest
  /// [entry]. This is the one place a download is actually trusted: bytes that
  /// do not match the signed checksum are rejected with a loud, honest error.
  Future<void> _verifyChecksum(
      String url, ManifestEntry entry, String label) async {
    final l = L10n.of(context);
    Toast.show(context, l.t('verifying_checksum'));
    try {
      final r = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      if (r.statusCode < 200 || r.statusCode >= 300) {
        if (mounted) Toast.show(context, '$label: ${l.t('pkg_missing')}', urgent: true);
        return;
      }
      final got = await sha256Hex(r.bodyBytes);
      if (!mounted) return;
      if (got == entry.sha256) {
        Toast.show(context, '$label: ${l.t('checksum_ok')}');
      } else {
        Toast.show(context, '$label: ${l.t('checksum_mismatch')}', urgent: true);
      }
    } catch (_) {
      if (mounted) Toast.show(context, '$label: ${l.t('pkg_unreachable')}', urgent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final outline = Theme.of(context).colorScheme.outline;
    final nodes = ref.watch(nodesProvider).valueOrNull ?? const <SavedNode>[];
    final active = ref.watch(activeNodeIdProvider).valueOrNull;
    final node = _selected(nodes, active);
    final library = ref.watch(packagesProvider).valueOrNull ?? const <SavedPackage>[];
    const head = TextStyle(
        fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w700);

    return Scaffold(
      appBar: AppBar(title: Text(l.t('offline_downloads'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_pkg',
        onPressed: _addManual,
        icon: const Icon(Icons.add_rounded),
        label: Text(l.t('add_package')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text(l.t('downloads_explainer'),
                style: TextStyle(
                    fontFamily: 'Roboto', fontSize: 16, color: outline)),
            const SizedBox(height: 12),
            // First-run prompt: how to download the offline map + the storage
            // screen for region packs, with the honest Cloud/Node source in use.
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ListTile(
                leading: const Icon(Icons.download_for_offline_rounded),
                title: Text(l.t('how_to_download_title'),
                    style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                subtitle: Text([
                  l.t('how_to_download_body'),
                  if (_preferredSource != PackSource.none)
                    l.t('using_source').replaceAll('{source}',
                        _preferredSource == PackSource.node
                            ? l.t('source_node')
                            : l.t('source_cloud')),
                ].join('\n\n'),
                    style: TextStyle(
                        fontFamily: 'Roboto', fontSize: 16, color: outline)),
                trailing: const Icon(Icons.chevron_right_rounded),
                isThreeLine: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const StorageScreen())),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.t('from_a_node'), style: head),
            const SizedBox(height: 8),
            if (node == null) ...[
              Text(l.t('no_nodes_hint'),
                  style: TextStyle(
                      fontFamily: 'Roboto', fontSize: 16, color: outline)),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NodesScreen())),
                icon: const Icon(Icons.router_rounded),
                label: Text(l.t('add_node')),
              ),
            ] else ...[
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: node.id,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.t('resilience_node')),
                    items: [
                      for (final n in nodes)
                        DropdownMenuItem(
                            value: n.id,
                            child: Text('${n.name} · ${n.url}',
                                overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() {
                      _nodeId = v;
                      _load = _Load.idle;
                      _catalog = const [];
                    }),
                  ),
                ),
                IconButton(
                  tooltip: l.t('saved_nodes'),
                  icon: const Icon(Icons.settings_ethernet_rounded),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NodesScreen())),
                ),
              ]),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load == _Load.loading ? null : () => _fetch(node),
                icon: const Icon(Icons.network_check_rounded),
                label: Text(l.t('check_node')),
              ),
              const SizedBox(height: 12),
              switch (_load) {
                _Load.idle => Text(l.t('node_not_set'),
                    style: TextStyle(
                        fontFamily: 'Roboto', fontSize: 16, color: outline)),
                _Load.loading => const SkeletonList(),
                _Load.unreachable => Text(l.t('pkg_unreachable'),
                    style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.error)),
                _Load.ok when _catalog.isEmpty => Text(l.t('node_has_nothing'),
                    style: TextStyle(
                        fontFamily: 'Roboto', fontSize: 16, color: outline)),
                _ => Column(children: [
                    _ManifestBanner(state: _manifestState),
                    for (final it in _catalog)
                      Builder(builder: (_) {
                        final url = '${node.url}${it.path}';
                        final verified = _manifestEntryForUrl(url) != null;
                        return Card(
                          child: ListTile(
                            leading: Icon(_iconOf(_kindOf(it.kind))),
                            title: Text(it.name),
                            subtitle: Text([
                              _size(it.sizeBytes),
                              _date(it.modifiedMs),
                              if (verified) l.t('checksum_available'),
                            ].where((s) => s.isNotEmpty).join(' · ')),
                            trailing: PopupMenuButton<String>(
                              tooltip: l.t('actions'),
                              onSelected: (v) {
                                switch (v) {
                                  case 'open':
                                    _open(url);
                                  case 'copy':
                                    _copy(url);
                                  case 'save':
                                    _saveToLibrary(node, it);
                                  case 'verify':
                                    final e = _manifestEntryForUrl(url);
                                    if (e != null) {
                                      _verifyChecksum(url, e, it.name);
                                    }
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                    value: 'open', child: Text(l.t('download'))),
                                PopupMenuItem(
                                    value: 'save',
                                    child: Text(l.t('save_to_library'))),
                                if (verified)
                                  PopupMenuItem(
                                      value: 'verify',
                                      child: Text(l.t('verify_checksum'))),
                                PopupMenuItem(
                                    value: 'copy', child: Text(l.t('copy_link'))),
                              ],
                            ),
                          ),
                        );
                      }),
                  ]),
              },
            ],
            const SizedBox(height: 24),
            Text(l.t('my_library'), style: head),
            const SizedBox(height: 8),
            if (library.isEmpty)
              Text(l.t('library_empty'),
                  style: TextStyle(
                      fontFamily: 'Roboto', fontSize: 16, color: outline))
            else
              for (final p in library)
                Card(
                  child: ListTile(
                    isThreeLine: true,
                    leading: Icon(_iconOf(p.kind)),
                    title: Text(p.name),
                    subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text([
                            if (p.version.isNotEmpty) '${l.t('version')} ${p.version}',
                            _size(p.sizeBytes),
                          ].where((s) => s.isNotEmpty).join(' · ')),
                          Text(p.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: outline)),
                          if (p.notes.isNotEmpty) Text(p.notes),
                        ]),
                    trailing: PopupMenuButton<String>(
                      tooltip: l.t('actions'),
                      onSelected: (v) {
                        switch (v) {
                          case 'open':
                            _open(p.url);
                          case 'copy':
                            _copy(p.url);
                          case 'check':
                            _check(p);
                          case 'edit':
                            _edit(p);
                          case 'delete':
                            _delete(p);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'open', child: Text(l.t('download'))),
                        PopupMenuItem(
                            value: 'check', child: Text(l.t('check_link'))),
                        PopupMenuItem(
                            value: 'copy', child: Text(l.t('copy_link'))),
                        PopupMenuItem(value: 'edit', child: Text(l.t('edit'))),
                        PopupMenuItem(
                            value: 'delete', child: Text(l.t('remove'))),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// An honest one-line status of the node's signed package manifest. It never
/// implies verification the app did not actually perform.
class _ManifestBanner extends StatelessWidget {
  final _Manifest state;
  const _ManifestBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state == _Manifest.none) return const SizedBox.shrink();
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color, String key) = switch (state) {
      _Manifest.verified => (
          Icons.verified_rounded,
          scheme.primary,
          'manifest_verified'
        ),
      _Manifest.untrusted => (
          Icons.gpp_maybe_outlined,
          scheme.error,
          'manifest_untrusted'
        ),
      _Manifest.unavailable => (
          Icons.info_outline_rounded,
          scheme.outline,
          'manifest_unavailable'
        ),
      _Manifest.none => (Icons.info_outline_rounded, scheme.outline, ''),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(l.t(key),
              style: TextStyle(
                  fontFamily: 'Roboto', fontSize: 16, color: color)),
        ),
      ]),
    );
  }
}

/// Add / edit one saved package version.
class _PackageDialog extends StatefulWidget {
  final SavedPackage initial;
  const _PackageDialog({required this.initial});
  @override
  State<_PackageDialog> createState() => _PackageDialogState();
}

class _PackageDialogState extends State<_PackageDialog> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _version = TextEditingController(text: widget.initial.version);
  late final _url = TextEditingController(text: widget.initial.url);
  late final _notes = TextEditingController(text: widget.initial.notes);
  late PackageKind _kind = widget.initial.kind;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _version.dispose();
    _url.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return AlertDialog(
      title: Text(widget.initial.id.isEmpty ? l.t('add_package') : l.t('edit')),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<PackageKind>(
            initialValue: _kind,
            decoration: InputDecoration(labelText: l.t('package_type')),
            items: [
              DropdownMenuItem(
                  value: PackageKind.app, child: Text(l.t('pkg_app'))),
              DropdownMenuItem(
                  value: PackageKind.map, child: Text(l.t('pkg_map'))),
              DropdownMenuItem(
                  value: PackageKind.readiness, child: Text(l.t('pkg_readiness'))),
              DropdownMenuItem(
                  value: PackageKind.other, child: Text(l.t('cat_other'))),
            ],
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
          TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l.t('node_name'))),
          TextField(
              controller: _version,
              decoration: InputDecoration(
                  labelText: l.t('version'), hintText: l.t('version_hint'))),
          TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: l.t('link'))),
          TextField(
              controller: _notes,
              decoration: InputDecoration(labelText: l.t('notes'))),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l.t('cancel'))),
        FilledButton(
          onPressed: () {
            final uri = Uri.tryParse(_url.text.trim());
            final okUrl = uri != null &&
                (uri.scheme == 'http' || uri.scheme == 'https') &&
                uri.host.isNotEmpty;
            if (_name.text.trim().isEmpty || !okUrl) {
              setState(() => _error = l.t('package_invalid'));
              return;
            }
            Navigator.pop(
                context,
                widget.initial.copyWith(
                    kind: _kind,
                    name: _name.text.trim(),
                    version: _version.text.trim(),
                    url: _url.text.trim(),
                    notes: _notes.text.trim()));
          },
          child: Text(l.t('save')),
        ),
      ],
    );
  }
}
