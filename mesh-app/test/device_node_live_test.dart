import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mesh_app/data/node_client.dart';
import 'package:mesh_app/data/wire/event_codec.dart';
import 'package:mesh_app/models/envelope.dart';
import 'package:mesh_app/state/identity.dart';

/// Talks to a real Resilience Node. Skipped unless NODE_LIVE_URL is set:
///
///   (in node/) go run ./cmd/resilience-node -http-addr 127.0.0.1:18090
///   NODE_LIVE_URL=http://127.0.0.1:18090 flutter test test/device_node_live_test.dart
void main() {
  final url = Platform.environment['NODE_LIVE_URL'];

  test('the Node stores what this phone signs, and gives it back', () async {
    final identity = await Identity.generate();
    final codec = EventCodec(identity);
    final client = NodeClient(baseUrl: url);
    addTearDown(client.close);
    expect(await client.healthy(), isTrue);

    Envelope envelope(String id, EnvelopeKind kind, {Map<String, Object?> fields = const {}, LatLng? at}) => Envelope(
          id: id,
          kind: kind,
          subject: 'live-$id',
          author: identity.resilienceId,
          createdAt: DateTime.now(),
          fields: fields,
          location: at,
        );

    final sent = [
      envelope('a', EnvelopeKind.helpRequest,
          fields: {'kind': 'water', 'urgency': 'soon', 'note': 'Live check', 'locationNote': 'Gym'},
          at: const LatLng(37.3352, -121.8811)),
      envelope('b', EnvelopeKind.sos, at: const LatLng(37.3353, -121.8812)),
      envelope('c', EnvelopeKind.helpCancelled),
      envelope('d', EnvelopeKind.resourceCreated,
          fields: {'kind': 'water', 'name': 'Live water'}, at: const LatLng(37.3354, -121.8813)),
      envelope('e', EnvelopeKind.vote, fields: {'vote': 'confirm'}),
      envelope('f', EnvelopeKind.vote),
      envelope('g', EnvelopeKind.message,
          fields: {'channelId': 'water', 'channelType': 'public', 'text': 'Hello from the app'}),
      envelope('h', EnvelopeKind.offer, fields: {'kinds': ['water', 'blankets'], 'amount': 'some'}),
      envelope('i', EnvelopeKind.missionAccepted),
      envelope('j', EnvelopeKind.packagePickedUp, fields: {'packageId': '8192'}),
      envelope('k', EnvelopeKind.locationStopped),
      envelope('l', EnvelopeKind.resourceRemoved),
    ];
    final events = [for (final e in sent) await codec.encode(e)];
    final ack = await client.push(events);
    expect(ack.rejected, isEmpty);
    expect(ack.applied, {for (final e in events) e.idHex});

    // Pushing again is harmless: same ids, nothing stored twice.
    final again = await client.push(events.take(2).toList());
    expect(again.applied, {events[0].idHex, events[1].idHex});

    final mine = hexOf(identity.publicKey);
    final pulled = await client.pull(from: {mine: 0});
    final back = pulled.where((e) => hexOf(e.author) == mine).toList();
    expect(back.map((e) => e.idHex), events.map((e) => e.idHex));
    for (final e in back) {
      expect(await e.verify(), isTrue);
    }
    final request = EventCodec.decode(back.first)!;
    expect((request.fields['kind'], request.fields['note']), ('water', 'Live check'));
    expect(request.location!.latitude, closeTo(37.3352, 1e-9));

    final heads = await client.have();
    expect(heads.firstWhere((h) => h.author == mine).highWater, events.length);
    final state = await client.state();
    expect(state.requests.map((r) => r['freeform']), contains('Live check'));
    expect(state.resources.map((r) => r['title']), contains('Live water'));
  }, skip: url == null ? 'set NODE_LIVE_URL to run against a real Node' : false);
}
