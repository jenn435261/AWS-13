import '../db/json_store.dart';

enum PackageKind { app, map, readiness, other }

/// One saved offline package version. Several entries may share a [name]
/// (different [version]s); [url] is where that exact version can be fetched.
class SavedPackage {
  final String id;
  final PackageKind kind;
  final String name;
  final String version;
  final String url;
  final String notes;
  final int sizeBytes;
  final int addedMs;
  const SavedPackage({
    required this.id,
    required this.kind,
    required this.name,
    required this.version,
    required this.url,
    this.notes = '',
    this.sizeBytes = 0,
    required this.addedMs,
  });

  SavedPackage copyWith(
          {PackageKind? kind,
          String? name,
          String? version,
          String? url,
          String? notes}) =>
      SavedPackage(
          id: id,
          kind: kind ?? this.kind,
          name: name ?? this.name,
          version: version ?? this.version,
          url: url ?? this.url,
          notes: notes ?? this.notes,
          sizeBytes: sizeBytes,
          addedMs: addedMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'name': name,
        'version': version,
        'url': url,
        'notes': notes,
        'sizeBytes': sizeBytes,
        'addedMs': addedMs,
      };

  static SavedPackage? fromJson(Map<String, dynamic> j) {
    final id = j['id'], name = j['name'], url = j['url'];
    if (id is! String || name is! String || url is! String) return null;
    return SavedPackage(
      id: id,
      kind: PackageKind.values.firstWhere((k) => k.name == j['kind'],
          orElse: () => PackageKind.other),
      name: name,
      version: j['version'] as String? ?? '',
      url: url,
      notes: j['notes'] as String? ?? '',
      sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
      addedMs: (j['addedMs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// CRUD for the user's library of offline package versions. Local-only.
class PackageStore {
  PackageStore(this._store);
  final JsonStore _store;

  Future<List<SavedPackage>> list() async {
    final all = (await _store.all())
        .map(SavedPackage.fromJson)
        .whereType<SavedPackage>()
        .toList();
    all.sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : b.addedMs.compareTo(a.addedMs);
    });
    return all;
  }

  Future<SavedPackage> add({
    required PackageKind kind,
    required String name,
    required String version,
    required String url,
    String notes = '',
    int sizeBytes = 0,
  }) async {
    final p = SavedPackage(
        id: 'p${DateTime.now().microsecondsSinceEpoch}',
        kind: kind,
        name: name,
        version: version,
        url: url,
        notes: notes,
        sizeBytes: sizeBytes,
        addedMs: DateTime.now().millisecondsSinceEpoch);
    await _store.put(p.id, p.toJson());
    return p;
  }

  Future<void> update(SavedPackage p) => _store.put(p.id, p.toJson());
  Future<void> remove(String id) => _store.delete(id);
}
