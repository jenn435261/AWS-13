import 'package:flutter/foundation.dart';

import '../../models/envelope.dart';
import '../../models/network.dart';

/// What a route said about a batch it took.
class TransportAck {
  const TransportAck({this.applied = const {}, this.rejected = const {}});

  /// Every envelope in [batch] was stored on the far side.
  factory TransportAck.all(Iterable<Envelope> batch) =>
      TransportAck(applied: {for (final e in batch) e.id});

  /// Envelope ids the far side stored. They are never sent again.
  final Set<String> applied;

  /// Envelope ids the far side refused for good (a bad signature or a
  /// revoked key). Sending them again would not help.
  final Set<String> rejected;
}

/// The link went away before the far side confirmed. Nothing in the batch
/// counts as delivered; the outbox tries again on this or another route.
class LinkDropped implements Exception {
  const LinkDropped([this.reason = '']);

  final String reason;

  @override
  String toString() => 'LinkDropped($reason)';
}

/// One way off the phone: nearby phones over Bluetooth or Wi-Fi, a LoRa
/// radio, a Resilience Node, or AWS. The [Outbox] decides what goes when;
/// a transport only moves bytes and reports its link.
abstract class MeshTransport {
  LinkKind get kind;

  /// Whether the link is up, and how many phones it reaches.
  ValueListenable<LinkStatus> get status;

  /// The most envelopes handed over in one [send].
  int get maxBatch => 1;

  /// Whether this route may carry [envelope] at all: it fits, and the
  /// route keeps it private enough.
  bool accepts(Envelope envelope) => true;

  /// Hands [batch] to the link, in order. Completes when the far side
  /// confirms; throws (usually [LinkDropped]) when the link fails first.
  Future<TransportAck> send(List<Envelope> batch);

  /// What other phones sent this one over this link.
  Stream<Envelope> get received => const Stream.empty();

  /// Starts looking for the link (asks for permissions where needed).
  Future<void> start() async {}

  void dispose();
}
