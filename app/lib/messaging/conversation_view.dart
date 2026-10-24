import 'dart:typed_data';

import '../core/event_factory.dart';
import '../gen/resilience/v1/event.pb.dart';
import 'message_flow.dart';

/// The transport/connection state surfaced to the UI. Set by the UI layer
/// later (this subsystem only models the field).
enum ConnectionState { internet, local, mesh, queued }

/// A single message in a [ConversationView].
class ConversationMessage {
  ConversationMessage({
    required this.messageId,
    required List<int> sender,
    required this.timestampMs,
    required this.lamport,
    required this.deliveryState,
    required this.priority,
    this.text,
    this.channelId = '',
    this.groupEpoch = 0,
  }) : sender = Uint8List.fromList(sender);

  final String messageId;
  final Uint8List sender;
  final int timestampMs;
  final int lamport;

  /// Delivery state derived from receipts in the log.
  final DeliveryState deliveryState;

  final Priority priority;

  /// Decrypted plaintext for the local user, or `null` if this message is not
  /// decryptable here (e.g. ciphertext for someone else, or no session).
  final String? text;

  final String channelId;
  final int groupEpoch;
}

/// A folded conversation for a Direct / Community / Mission channel.
///
/// Combines `MESSAGE_SENT` events with their `MESSAGE_DELIVERED` /
/// `MESSAGE_READ` receipts into an ordered list of [ConversationMessage]s, each
/// stamped with its [DeliveryState]. Decryption is supplied by the caller (so
/// this view stays independent of session wiring); [connectionState] is passed
/// in by the UI layer.
class ConversationView {
  ConversationView._({
    required this.channelId,
    required this.messages,
    required this.connectionState,
  });

  final String channelId;
  final List<ConversationMessage> messages;
  final ConnectionState connectionState;

  /// Fold [events] into a conversation for [channelId].
  ///
  /// [decrypt] is invoked for each `MESSAGE_SENT` in the channel to obtain the
  /// local plaintext; it may return `null` when the message is not decryptable
  /// locally. [hasRoute] drives whether undelivered messages read as
  /// `propagating` (a route exists) or `queued` (none yet).
  static Future<ConversationView> fold({
    required String channelId,
    required List<SignedEvent> events,
    Future<String?> Function(SignedEvent sent, MessageBody body)? decrypt,
    ConnectionState connectionState = ConnectionState.queued,
    bool hasRoute = true,
    EventFactory? factory,
  }) async {
    final EventFactory f = factory ?? EventFactory();

    final List<SignedEvent> sent = <SignedEvent>[];
    for (final SignedEvent e in events) {
      if (e.header.type != EventType.EVENT_TYPE_MESSAGE_SENT) continue;
      if (!await f.verifyEvent(e)) continue;
      final MessageBody body = MessageBody.fromBuffer(e.body);
      if (body.channelId != channelId) continue;
      sent.add(e);
    }

    // Deterministic order: lamport asc, then event id.
    sent.sort((a, b) {
      final int la = a.header.lamport.toInt();
      final int lb = b.header.lamport.toInt();
      if (la != lb) return la - lb;
      return _compareBytes(a.header.eventId, b.header.eventId);
    });

    final List<ConversationMessage> msgs = <ConversationMessage>[];
    for (final SignedEvent e in sent) {
      final MessageBody body = MessageBody.fromBuffer(e.body);
      final String? text = decrypt == null ? null : await decrypt(e, body);
      final DeliveryState state = MessageFlow.deliveryState(
        body.messageId,
        events,
        hasRoute: hasRoute,
      );
      msgs.add(ConversationMessage(
        messageId: body.messageId,
        sender: e.header.authorPubkey,
        timestampMs: e.header.createdAtMs.toInt(),
        lamport: e.header.lamport.toInt(),
        deliveryState: state,
        priority: body.priority,
        text: text,
        channelId: body.channelId,
        groupEpoch: body.groupEpoch,
      ));
    }

    return ConversationView._(
      channelId: channelId,
      messages: List<ConversationMessage>.unmodifiable(msgs),
      connectionState: connectionState,
    );
  }

  static int _compareBytes(List<int> a, List<int> b) {
    final int n = a.length < b.length ? a.length : b.length;
    for (int i = 0; i < n; i++) {
      final int d = a[i] - b[i];
      if (d != 0) return d;
    }
    return a.length - b.length;
  }
}
