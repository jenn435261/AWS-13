import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/event_store.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/db/database.dart';
import 'package:resilience/db/event_dao.dart';
import 'package:resilience/db/json_store.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';
import 'package:resilience/gen/resilience/v1/sync.pb.dart';
import 'package:resilience/sync/cloud_sync.dart';

/// A fake cloud/node that speaks the same JSON wire protocol as the real cloud
/// API and node sync server, backed by a second [EventStore]. Because it
/// ingests every pushed event through [EventStore.apply] (verify-then-store),
/// it rejects forged events exactly like the production servers do — which is
/// what lets this test prove the abuse case end to end with no real network.
class FakeServerHttp implements SyncHttp {
  FakeServerHttp(this.server);

  final EventStore server;

  /// Records the X-Api-Key seen on the last request (to assert the header is
  /// sent when configured).
  String? lastApiKey;

  @override
  Future<SyncHttpResponse> post(
    Uri url,
    Map<String, String> headers,
    List<int> body,
  ) async {
    lastApiKey = headers['X-Api-Key'];
    final json = body.isEmpty ? <String, dynamic>{} : jsonDecode(utf8.decode(body));

    if (url.path.endsWith('/pull')) {
      final req = PullEventsRequest.create()..mergeFromProto3Json(json);
      final digest = <AuthorKey, int>{};
      for (final af in req.from) {
        digest[AuthorKey(af.authorPubkey)] = af.fromLamport.toInt();
      }
      final missing = await server.missingFrom(digest);
      final resp = PullEventsResponse(
        batch: EventBatch(events: missing, more: false),
      );
      return _ok(resp.toProto3Json());
    }

    // Push: /v1/events or /node/v1/push.
    final req = PushEventsRequest.create()..mergeFromProto3Json(json);
    final applied = <List<int>>[];
    final rejected = <List<int>>[];
    for (final e in req.events) {
      final r = await server.apply(e);
      if (r.isInvalid) {
        rejected.add(e.header.eventId);
      } else {
        applied.add(e.header.eventId);
      }
    }
    final resp = PushEventsResponse(
      ack: Ack(applied: applied, rejected: rejected),
    );
    return _ok(resp.toProto3Json());
  }

  SyncHttpResponse _ok(Object? proto3Json) =>
      SyncHttpResponse(200, utf8.encode(jsonEncode(proto3Json)));
}

/// A fake that always fails the connection, to prove honest error handling.
class DownHttp implements SyncHttp {
  @override
  Future<SyncHttpResponse> post(
    Uri url,
    Map<String, String> headers,
    List<int> body,
  ) async {
    throw Exception('connection refused');
  }
}

ResourceBody _body(String title) => ResourceBody(
      resourceId: title,
      category: ResourceCategory.RESOURCE_CATEGORY_WATER,
      title: title,
      amount: AmountBand.AMOUNT_BAND_SOME,
      availability: Availability.AVAILABILITY_NOW,
      provenance: ProvenanceKind.PROVENANCE_KIND_COMMUNITY,
    );

void main() {
  late AppDatabase clientDb;
  late AppDatabase serverDb;
  late EventStore clientStore;
  late EventStore serverStore;
  late JsonStore cursors;
  late Signer signer;
  late EventFactory factory;
  late KeyPairData alice; // the local device (us)
  late KeyPairData bob; // a remote author whose events live on the server
  late LamportClock aliceClock;
  late LamportClock bobClock;

  setUp(() async {
    clientDb = AppDatabase.memory();
    serverDb = AppDatabase.memory();
    signer = Signer();
    factory = EventFactory(signer: signer);
    clientStore =
        EventStore(dao: clientDb.eventDao, factory: factory, clock: LamportClock());
    serverStore =
        EventStore(dao: serverDb.eventDao, factory: factory, clock: LamportClock());
    cursors = JsonStore(clientDb, 'sync:');
    alice = await signer.generateKeyPair();
    bob = await signer.generateKeyPair();
    aliceClock = LamportClock();
    bobClock = LamportClock();
  });

  tearDown(() async {
    await clientDb.close();
    await serverDb.close();
  });

  Future<SignedEvent> make(
    KeyPairData kp,
    LamportClock clock,
    String title, {
    List<int>? prev,
  }) {
    return factory.buildFromMessage(
      keyPair: kp,
      clock: clock,
      type: EventType.EVENT_TYPE_RESOURCE_CREATED,
      body: _body(title),
      prevEventId: prev,
    );
  }

  Future<Set<String>> idsOf(AppDatabase db) async {
    final ids = await db.eventDao.allEventIds();
    return ids.map(_hex).toSet();
  }

  CloudSync buildSync(SyncHttp http, {String apiKey = ''}) => CloudSync(
        store: clientStore,
        baseUrl: 'http://cloud.test',
        http: http,
        cursors: cursors,
        myAuthorPubkey: Uint8List.fromList(alice.publicKey),
        apiKey: apiKey,
        kind: SyncEndpointKind.cloud,
      );

  test('pushes local events to the peer and reports them', () async {
    // Alice has 3 local events; the server has none.
    List<int>? prev;
    for (int i = 0; i < 3; i++) {
      final e = await make(alice, aliceClock, 'a$i', prev: prev);
      prev = e.header.eventId;
      await clientStore.apply(e);
    }

    final sync = buildSync(FakeServerHttp(serverStore), apiKey: 'secret-key');
    final out = await sync.syncOnce();

    expect(out.ok, isTrue, reason: out.error);
    expect(out.pushed, 3);
    expect(out.pending, 0, reason: 'everything local is now on the peer');
    // The server received all 3 valid events.
    expect(await idsOf(serverDb), hasLength(3));
  });

  test('sends the X-Api-Key header when configured', () async {
    await clientStore.apply(await make(alice, aliceClock, 'a0'));
    final http = FakeServerHttp(serverStore);
    await buildSync(http, apiKey: 'secret-key').syncOnce();
    expect(http.lastApiKey, 'secret-key');
  });

  test('pulls remote events and applies them through the EventStore', () async {
    // Bob authored 4 events that live only on the server.
    List<int>? prev;
    for (int i = 0; i < 4; i++) {
      final e = await make(bob, bobClock, 'b$i', prev: prev);
      prev = e.header.eventId;
      await serverStore.apply(e);
    }

    final sync = buildSync(FakeServerHttp(serverStore));
    final out = await sync.syncOnce();

    expect(out.ok, isTrue, reason: out.error);
    expect(out.applied, 4);
    // The client now holds Bob's 4 events (ingested via apply, so verified).
    expect(await idsOf(clientDb), hasLength(4));
  });

  test('a forged/tampered pulled event is rejected and never stored', () async {
    // One valid event from Bob on the server.
    final valid = await make(bob, bobClock, 'valid');
    await serverStore.apply(valid);

    // A second event whose signature is corrupted. Insert it straight into the
    // SERVER dao (bypassing verification) so it is offered on pull, simulating
    // a malicious or corrupt peer.
    final willTamper =
        await make(bob, bobClock, 'evil', prev: valid.header.eventId);
    final tampered = willTamper.deepCopy();
    final sig = Uint8List.fromList(tampered.signature);
    sig[0] ^= 0xFF;
    tampered.signature = sig;
    await serverDb.eventDao.insertEvent(tampered, valid: false);

    final sync = buildSync(FakeServerHttp(serverStore));
    final out = await sync.syncOnce();

    expect(out.ok, isTrue, reason: out.error);
    // Exactly one event applied (the valid one), one rejected (the forged one).
    expect(out.applied, 1);
    expect(out.rejected, greaterThanOrEqualTo(1));

    final clientIds = await idsOf(clientDb);
    expect(clientIds.contains(_hex(valid.header.eventId)), isTrue);
    expect(clientIds.contains(_hex(tampered.header.eventId)), isFalse,
        reason: 'the forged event must never be stored');
  });

  test('pending count tracks un-pushed local events', () async {
    final sync = buildSync(FakeServerHttp(serverStore));

    // Two local events before the first sync.
    List<int>? prev;
    for (int i = 0; i < 2; i++) {
      final e = await make(alice, aliceClock, 'a$i', prev: prev);
      prev = e.header.eventId;
      await clientStore.apply(e);
    }

    final out1 = await sync.syncOnce();
    expect(out1.pending, 0, reason: 'both pushed');

    // Author one more AFTER syncing: it should now be pending until the next
    // sync.
    final head = await clientDb.eventDao.headByAuthor(alice.publicKey);
    final e = await make(alice, aliceClock, 'a2', prev: head!.header.eventId);
    await clientStore.apply(e);

    final out2 = await sync.syncOnce();
    expect(out2.pushed, 1);
    expect(out2.pending, 0);
  });

  test('sync is idempotent: a second run transfers nothing', () async {
    // Mixed state: Alice local, Bob remote.
    await clientStore.apply(await make(alice, aliceClock, 'a0'));
    await serverStore.apply(await make(bob, bobClock, 'b0'));

    final sync = buildSync(FakeServerHttp(serverStore));
    final first = await sync.syncOnce();
    expect(first.pushed, 1);
    expect(first.applied, 1);

    final second = await sync.syncOnce();
    expect(second.pushed, 0, reason: 'nothing new to push');
    expect(second.applied, 0, reason: 'nothing new to pull');
    expect(second.pending, 0);
    expect(second.ok, isTrue);

    // Both sides converged to the union (2 events each).
    expect(await idsOf(clientDb), hasLength(2));
    expect(await idsOf(serverDb), hasLength(2));
  });

  test('a down endpoint sets a truthful error and never throws', () async {
    await clientStore.apply(await make(alice, aliceClock, 'a0'));
    final sync = buildSync(DownHttp());
    final out = await sync.syncOnce();
    expect(out.ok, isFalse);
    expect(out.error, isNotNull);
    // The local event is still counted as pending (not lost).
    expect(out.pending, 1);
  });

  test('a non-200 response is reported as an error, not a crash', () async {
    await clientStore.apply(await make(alice, aliceClock, 'a0'));
    final sync = buildSync(_StatusHttp(503, '{"error":"not ready"}'));
    final out = await sync.syncOnce();
    expect(out.ok, isFalse);
    expect(out.error, contains('503'));
  });
}

/// A fake that always returns a fixed status + body (for error-path tests).
class _StatusHttp implements SyncHttp {
  _StatusHttp(this.status, this.body);
  final int status;
  final String body;

  @override
  Future<SyncHttpResponse> post(
    Uri url,
    Map<String, String> headers,
    List<int> body,
  ) async =>
      SyncHttpResponse(status, utf8.encode(this.body));
}

String _hex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
