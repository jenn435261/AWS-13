import '../db/json_store.dart';

/// The download/verification state of one region pack on the device.
enum PackStatus {
  /// Some chunks are present but the pack is not fully verified (resume shows
  /// `N% of a pack, resume`).
  partial,

  /// Every entry downloaded and its SHA-256 matched the signed manifest.
  verified,
}

/// A region pack the user chose to download with "Prepare now": a bundle of a
/// map tile pack plus the sidecar data (events in radius, safe places,
/// supplies, shelters, guidance) for a region. Metadata only — the bytes live
/// in the [ChunkStore]. Local-only.
class RegionPack {
  final String id; // stable, e.g. `region:lat,lon,radius`
  final String name; // human label, e.g. "Downtown"
  final String source; // "Cloud" | "Node"
  final String baseUrl; // where the pack was fetched from
  final int totalBytes; // sum of entry sizes (for the MB consent + storage screen)
  final int downloadedBytes; // best-effort bytes stored so far
  final int percent; // 0..100 of the map pack download
  final PackStatus status;
  final int updatedMs;

  const RegionPack({
    required this.id,
    required this.name,
    required this.source,
    required this.baseUrl,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.percent,
    required this.status,
    required this.updatedMs,
  });

  RegionPack copyWith({
    int? downloadedBytes,
    int? percent,
    PackStatus? status,
    int? updatedMs,
    int? totalBytes,
  }) =>
      RegionPack(
        id: id,
        name: name,
        source: source,
        baseUrl: baseUrl,
        totalBytes: totalBytes ?? this.totalBytes,
        downloadedBytes: downloadedBytes ?? this.downloadedBytes,
        percent: percent ?? this.percent,
        status: status ?? this.status,
        updatedMs: updatedMs ?? this.updatedMs,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source,
        'baseUrl': baseUrl,
        'totalBytes': totalBytes,
        'downloadedBytes': downloadedBytes,
        'percent': percent,
        'status': status.name,
        'updatedMs': updatedMs,
      };

  static RegionPack? fromJson(Map<String, dynamic> j) {
    final id = j['id'], name = j['name'];
    if (id is! String || name is! String) return null;
    return RegionPack(
      id: id,
      name: name,
      source: j['source'] as String? ?? 'Cloud',
      baseUrl: j['baseUrl'] as String? ?? '',
      totalBytes: (j['totalBytes'] as num?)?.toInt() ?? 0,
      downloadedBytes: (j['downloadedBytes'] as num?)?.toInt() ?? 0,
      percent: (j['percent'] as num?)?.toInt() ?? 0,
      status: PackStatus.values.firstWhere((s) => s.name == j['status'],
          orElse: () => PackStatus.partial),
      updatedMs: (j['updatedMs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// CRUD for the user's downloaded region packs (metadata). Local-only, in the
/// KeyValue table under the `regionpack:` prefix.
class RegionPackStore {
  RegionPackStore(this._store);
  final JsonStore _store;

  Future<List<RegionPack>> list() async {
    final all = (await _store.all())
        .map(RegionPack.fromJson)
        .whereType<RegionPack>()
        .toList();
    all.sort((a, b) => b.updatedMs.compareTo(a.updatedMs));
    return all;
  }

  Future<RegionPack?> get(String id) async {
    for (final p in await list()) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> upsert(RegionPack pack) => _store.put(pack.id, pack.toJson());

  Future<void> remove(String id) => _store.delete(id);

  /// Stores a small sidecar JSON snapshot for a region (e.g. a count of cached
  /// alerts/safe-places). This is dynamic convenience data, NOT manifest-signed,
  /// kept under a distinct `sidecar:` sub-key so it never appears in [list].
  Future<void> upsertSidecar(String regionId, Map<String, dynamic> data) =>
      _store.put('sidecar:$regionId', {...data, '_sidecar': regionId});
}
