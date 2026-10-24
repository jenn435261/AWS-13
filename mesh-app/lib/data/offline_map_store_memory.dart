import 'offline_map_store.dart';

/// The web preview has no files, so it keeps the map in memory.
OfflineMapStore deviceOfflineMapStore() => MemoryOfflineMapStore();
