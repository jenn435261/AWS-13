import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/json_store.dart';
import 'blob_transport.dart';
import 'messaging_service.dart';

/// The blob transport used for encrypted attachments: the cloud (client-key
/// gated) and the active node, whichever are configured. Reads/writes only
/// ciphertext.
final blobTransportProvider = FutureProvider<BlobTransport>((ref) async {
  final endpoints = <BlobEndpoint>[];
  final cloudBase = ref.watch(cloudBaseUrlProvider).replaceAll(RegExp(r'/+$'), '');
  final apiKey = ref.watch(cloudApiKeyProvider);
  if (cloudBase.isNotEmpty) {
    endpoints.add(BlobEndpoint(
      baseUrl: cloudBase,
      path: '/v1/blobs/',
      apiKey: apiKey,
    ));
  }
  final activeId = await ref.watch(activeNodeIdProvider.future);
  if (activeId != null) {
    final nodes = await ref.watch(nodesProvider.future);
    final matches = nodes.where((n) => n.id == activeId);
    if (matches.isNotEmpty) {
      final base = matches.first.url.replaceAll(RegExp(r'/+$'), '');
      if (base.isNotEmpty) {
        endpoints.add(BlobEndpoint(baseUrl: base, path: '/node/v1/blobs/'));
      }
    }
  }
  return HttpBlobTransport(endpoints: endpoints);
});

/// The messaging service for the current identity. Null-safe: requires the
/// device identity, the durable Signal store, the event store and a blob
/// transport.
final messagingServiceProvider = FutureProvider<MessagingService>((ref) async {
  final id = await ref.watch(identityProvider.future);
  final kp = await authorKeyPair(id);
  final db = ref.watch(databaseProvider);
  final blob = await ref.watch(blobTransportProvider.future);
  final svc = MessagingService(
    store: ref.watch(eventStoreProvider),
    signalDao: db.signalDao,
    factory: ref.watch(eventFactoryProvider),
    clock: ref.watch(lamportClockProvider),
    selfKeyPair: kp,
    blob: blob,
    mirrorStore: JsonStore(db, 'msgmirror:'),
  );
  // Publish our prekey bundle so contacts can start a session with us.
  await svc.publishMyBundle();
  return svc;
});

/// Bumped after a message is sent so the open conversation reloads.
final messagesRevisionProvider = StateProvider<int>((ref) => 0);
