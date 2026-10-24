import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/envelope.dart';
import '../../models/network.dart';
import '../wire/event_codec.dart';
import 'mesh_transport.dart';

/// What the app needs from an MQTT client to talk to AWS IoT Core. A real
/// one (MQTT 3.1.1 over TLS on port 8883 with the device certificate, or
/// over WebSockets with Cognito credentials) plugs in here later; the app
/// does not ship one yet.
abstract class MqttConnection {
  ValueListenable<bool> get connected;

  Future<void> connect();

  /// Publishes with QoS 1. Completes when the broker's PUBACK arrives;
  /// throws if the connection drops first.
  Future<void> publish(String topic, Uint8List payload);

  /// Messages on topics matching [filter] (QoS 1).
  Stream<(String, Uint8List)> subscribe(String filter);

  void dispose();
}

/// SUGGESTED topic layout, for the backend partner to accept or change.
/// Nothing in the app depends on these names except this class.
class CloudTopics {
  const CloudTopics({this.prefix = 'resilience/v1'});

  final String prefix;

  /// Phone to cloud: one signed event per message.
  String events(String deviceId) => '$prefix/devices/$deviceId/events';

  /// Cloud to one phone: replies, receipts, events meant for it.
  String inbox(String deviceId) => '$prefix/devices/$deviceId/inbox';

  /// Cloud to everyone in an area: alerts and public events.
  String area(String areaId) => '$prefix/areas/$areaId/events';
}

/// AWS over this phone's own internet, through [MqttConnection]. Each
/// envelope is one `resilience.v1.SignedEvent` (protobuf bytes) on
/// [CloudTopics.events]; the broker's PUBACK is the confirmation.
class CloudTransport extends MeshTransport {
  CloudTransport({
    required this.mqtt,
    required this.codec,
    this.topics = const CloudTopics(),
  }) {
    mqtt.connected.addListener(_sync);
    _sync();
  }

  final MqttConnection mqtt;
  final EventCodec codec;
  final CloudTopics topics;

  final _status = ValueNotifier(const LinkStatus(kind: LinkKind.cloud, up: false));

  String get _deviceId => codec.identity.resilienceId;

  @override
  LinkKind get kind => LinkKind.cloud;

  @override
  ValueListenable<LinkStatus> get status => _status;

  @override
  int get maxBatch => 20;

  /// The cloud stores what it relays, so private items wait for
  /// end-to-end encryption.
  @override
  bool accepts(Envelope envelope) => !envelope.needsEndToEnd && codec.canEncode(envelope);

  void _sync() => _status.value = LinkStatus(
        kind: LinkKind.cloud,
        up: mqtt.connected.value,
        reachesCloud: true,
      );

  @override
  Future<void> start() => mqtt.connect();

  @override
  Future<TransportAck> send(List<Envelope> batch) async {
    final applied = <String>{};
    for (final e in batch) {
      final event = await codec.encode(e);
      try {
        await mqtt.publish(topics.events(_deviceId), event.toBytes());
      } on Object catch (err) {
        // What was acknowledged so far stays acknowledged.
        if (applied.isNotEmpty) return TransportAck(applied: applied);
        throw LinkDropped('$err');
      }
      applied.add(e.id);
    }
    return TransportAck(applied: applied);
  }

  @override
  void dispose() {
    mqtt.connected.removeListener(_sync);
    _status.dispose();
    mqtt.dispose();
  }
}

/// Plays AWS IoT Core's broker for tests and previews.
class SimulatedMqttConnection implements MqttConnection {
  SimulatedMqttConnection({bool connected = false, this.latency = Duration.zero})
      : _connected = ValueNotifier(connected);

  final ValueNotifier<bool> _connected;
  final Duration latency;
  final _messages = StreamController<(String, Uint8List)>.broadcast();

  /// Everything the broker acknowledged, in order.
  final published = <(String, Uint8List)>[];

  /// Drops the connection on the next publish, before the PUBACK.
  bool dropNext = false;

  @override
  ValueListenable<bool> get connected => _connected;

  set online(bool on) => _connected.value = on;

  @override
  Future<void> connect() async => _connected.value = true;

  @override
  Future<void> publish(String topic, Uint8List payload) async {
    await Future<void>.delayed(latency);
    if (!_connected.value) throw StateError('not connected');
    if (dropNext) {
      dropNext = false;
      _connected.value = false;
      throw StateError('connection lost before PUBACK');
    }
    published.add((topic, payload));
  }

  @override
  Stream<(String, Uint8List)> subscribe(String filter) => _messages.stream.where(
        (m) => filter.endsWith('#')
            ? m.$1.startsWith(filter.substring(0, filter.length - 1))
            : m.$1 == filter,
      );

  /// Plays the cloud sending [payload] on [topic].
  void deliver(String topic, Uint8List payload) => _messages.add((topic, payload));

  @override
  void dispose() {
    _messages.close();
    _connected.dispose();
  }
}
