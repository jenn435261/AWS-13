import 'dart:convert';

import '../db/json_store.dart';

/// A Resilience Node the user has saved. [url] has no trailing slash.
class SavedNode {
  final String id;
  final String name;
  final String url;
  final int addedMs;
  const SavedNode(
      {required this.id,
      required this.name,
      required this.url,
      required this.addedMs});

  SavedNode copyWith({String? name, String? url}) => SavedNode(
      id: id, name: name ?? this.name, url: url ?? this.url, addedMs: addedMs);

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'url': url, 'addedMs': addedMs};

  static SavedNode? fromJson(Map<String, dynamic> j) {
    final id = j['id'], name = j['name'], url = j['url'];
    if (id is! String || name is! String || url is! String) return null;
    return SavedNode(
        id: id,
        name: name,
        url: url,
        addedMs: (j['addedMs'] as num?)?.toInt() ?? 0);
  }
}

/// What a node's pairing QR (or typed address) resolves to.
class NodeAddress {
  final String url;
  final String? name;
  const NodeAddress(this.url, [this.name]);
}

/// Accepts the node's pairing JSON (`{"v":1,"name":..,"url":..}`) or a bare
/// address ("192.168.1.20:8090", "http://host:8090/"). Returns null when the
/// text cannot be an http(s) address, so junk never gets saved.
NodeAddress? parseNodeAddress(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  String? name;
  if (text.startsWith('{')) {
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      text = (j['url'] as String? ?? '').trim();
      name = (j['name'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }
  if (!text.contains('://')) text = 'http://$text';
  final uri = Uri.tryParse(text);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      !RegExp(r'^[A-Za-z0-9._-]+$|^\[[0-9A-Fa-f:.]+\]$').hasMatch(uri.host) ||
      text.contains(RegExp(r'\s'))) {
    return null;
  }
  return NodeAddress('${uri.scheme}://${uri.authority}',
      (name == null || name.isEmpty) ? null : name);
}

/// CRUD for saved nodes plus which one is active. Local-only.
class NodeStore {
  NodeStore(this._nodes, this._settings);
  final JsonStore _nodes;
  final JsonStore _settings;

  Future<List<SavedNode>> list() async {
    final nodes = (await _nodes.all())
        .map(SavedNode.fromJson)
        .whereType<SavedNode>()
        .toList();
    nodes.sort((a, b) => a.addedMs.compareTo(b.addedMs));
    return nodes;
  }

  /// Saves a node, or returns/renames the existing entry with the same address.
  Future<SavedNode> add(String url, {String? name}) async {
    final existing = (await list()).where((n) => n.url == url);
    if (existing.isNotEmpty) {
      final n = existing.first;
      if (name != null && name.isNotEmpty && name != n.name) {
        final renamed = n.copyWith(name: name);
        await _nodes.put(n.id, renamed.toJson());
        return renamed;
      }
      return n;
    }
    final now = DateTime.now().microsecondsSinceEpoch;
    final node = SavedNode(
        id: 'n$now',
        name: (name == null || name.isEmpty) ? Uri.parse(url).host : name,
        url: url,
        addedMs: DateTime.now().millisecondsSinceEpoch);
    await _nodes.put(node.id, node.toJson());
    return node;
  }

  Future<void> rename(String id, String name) async {
    final n = (await list()).where((n) => n.id == id);
    if (n.isEmpty || name.trim().isEmpty) return;
    await _nodes.put(id, n.first.copyWith(name: name.trim()).toJson());
  }

  Future<void> remove(String id) async {
    await _nodes.delete(id);
    if (await activeId() == id) await _settings.delete('activeNode');
  }

  Future<String?> activeId() async {
    for (final r in await _settings.all()) {
      if (r['k'] == 'activeNode') return r['v'] as String?;
    }
    return null;
  }

  Future<void> setActive(String id) =>
      _settings.put('activeNode', {'k': 'activeNode', 'v': id});
}
