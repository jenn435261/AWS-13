import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';

import '../core/event_factory.dart';
import '../core/hashing.dart';
import '../core/lamport_clock.dart';
import '../core/signing.dart';
import '../gen/resilience/v1/event.pb.dart';
import 'secure_session.dart';

/// Delivery state of a message (spec §16).
///
/// Derived purely from the presence of events in the log:
///  * [queued] — a `MESSAGE_SENT` exists but no route has carried it yet (it
///    sits in the outbox / a relay's store);
///  * [propagating] — the `MESSAGE_SENT` is moving across relays (in flight)
///    but not yet confirmed delivered;
///  * [delivered] — a `MESSAGE_DELIVERED` receipt from the recipient exists;
///  * [read] — a `MESSAGE_READ` receipt from the recipient exists.
///
/// If no route ever exists the message stays [queued] indefinitely — the
/// store-carry-forward model guarantees it is delivered if and when a path
/// eventually appears.
enum DeliveryState { queued, propagating, delivered, read }

/// The outcome of [MessageFlow.sendDirect]: the signed `MESSAGE_SENT` event and
/// the message id assigned to it.
class SentMessage {
  SentMessage({required this.event, required this.messageId});
  final SignedEvent event;
  final String messageId;
}

/// Ties the Wave-1 Signal sessions to the event log.
///
/// A direct message is: encrypt the plaintext with a [SecureSession], wrap the
/// opaque ciphertext in a [MessageBody] whose `recipientHint` is a *hash* of
/// the recipient pubkey (never a name or phone number), and emit a
/// `MESSAGE_SENT` event via [EventFactory]. Relays only ever see the hint and
/// the ciphertext — they cannot read the message, yet they can carry it
/// (store-carry-forward) until it reaches the recipient, who recognizes the
/// hint, decrypts, and emits a `MESSAGE_DELIVERED` receipt.
///
/// ## Store-carry-forward
///
/// This falls out of the event-sync model for free: a `MESSAGE_SENT` event is
/// just another signed event in the DAG. Any relay that syncs it carries the
/// opaque ciphertext without being able to decrypt it; when the event finally
/// reaches a node whose [SecureSession] can decrypt it (the recipient), the
/// message is delivered. No online rendezvous between sender and recipient is
/// required.
class MessageFlow {
  MessageFlow({
    required this.selfKeyPair,
    required this.clock,
    required this.session,
    EventFactory? factory,
  }) : _factory = factory ?? EventFactory();

  /// The local user's signing keypair (authors MESSAGE_* events).
  final KeyPairData selfKeyPair;

  /// The local user's Lamport clock.
  final LamportClock clock;

  /// The established 1:1 Signal session toward the counterparty.
  final SecureSession session;

  final EventFactory _factory;

  int _messageCounter = 0;

  /// The opaque recipient hint for [recipientPubkey]: BLAKE2b-256 of the
  /// pubkey. Stable, non-reversible, and leaks no identity to relays.
  static Uint8List recipientHintFor(List<int> recipientPubkey) =>
      blake2b256(recipientPubkey);

  /// Whether [hint] addresses the holder of [pubkey].
  static bool hintMatches(List<int> hint, List<int> pubkey) {
    final Uint8List expected = recipientHintFor(pubkey);
    if (hint.length != expected.length) return false;
    for (int i = 0; i < hint.length; i++) {
      if (hint[i] != expected[i]) return false;
    }
    return true;
  }

  /// Encrypt [plaintext] toward the session peer, wrap it, and emit a signed
  /// `MESSAGE_SENT` event. The caller enqueues the returned event for transport
  /// (store-carry-forward handles the rest).
  Future<SentMessage> sendDirect({
    required List<int> recipientPubkey,
    required String plaintext,
    String channelId = '',
    String? messageId,
    Priority priority = Priority.PRIORITY_NORMAL,
  }) async {
    final String id = messageId ?? _nextMessageId();
    final Uint8List ciphertext = await session.encryptText(plaintext);

    final body = MessageBody(
      messageId: id,
      channelId: channelId,
      recipientHint: recipientHintFor(recipientPubkey),
      ciphertext: ciphertext,
      priority: priority,
    );
    final SignedEvent event = await _factory.buildFromMessage(
      keyPair: selfKeyPair,
      clock: clock,
      type: EventType.EVENT_TYPE_MESSAGE_SENT,
      body: body,
    );
    return SentMessage(event: event, messageId: id);
  }

  /// If [event] is a `MESSAGE_SENT` addressed to us, decrypt and return the
  /// plaintext; otherwise return `null`.
  ///
  /// When it is for us, a `MESSAGE_DELIVERED` receipt event is produced via
  /// [onReceipt] (if provided) so the sender's [DeliveryState] can advance.
  Future<String?> receive(
    SignedEvent event, {
    Future<void> Function(SignedEvent receipt)? onReceipt,
  }) async {
    if (event.header.type != EventType.EVENT_TYPE_MESSAGE_SENT) return null;
    if (!await _factory.verifyEvent(event)) return null;

    final MessageBody body = MessageBody.fromBuffer(event.body);
    if (!hintMatches(body.recipientHint, selfKeyPair.publicKey)) {
      // Not for us — we may still relay it (store-carry-forward), but we can't
      // (and shouldn't) read it.
      return null;
    }

    final String plaintext = await session.decryptText(
      Uint8List.fromList(body.ciphertext),
    );

    if (onReceipt != null) {
      final SignedEvent receipt = await _buildReceipt(
        type: EventType.EVENT_TYPE_MESSAGE_DELIVERED,
        messageId: body.messageId,
      );
      await onReceipt(receipt);
    }
    return plaintext;
  }

  /// Emit a `MESSAGE_READ` receipt for [messageId].
  Future<SignedEvent> markRead(String messageId) {
    return _buildReceipt(
      type: EventType.EVENT_TYPE_MESSAGE_READ,
      messageId: messageId,
    );
  }

  /// Emit a `MESSAGE_DELIVERED` receipt for [messageId] (exposed for callers
  /// that drive receipts themselves rather than via [receive]'s callback).
  Future<SignedEvent> markDelivered(String messageId) {
    return _buildReceipt(
      type: EventType.EVENT_TYPE_MESSAGE_DELIVERED,
      messageId: messageId,
    );
  }

  Future<SignedEvent> _buildReceipt({
    required EventType type,
    required String messageId,
  }) {
    final body = ReceiptBody(
      messageId: messageId,
      byPubkey: selfKeyPair.publicKey,
    );
    return _factory.buildFromMessage(
      keyPair: selfKeyPair,
      clock: clock,
      type: type,
      body: body,
    );
  }

  String _nextMessageId() {
    _messageCounter++;
    final String author = base64Url.encode(selfKeyPair.publicKey).substring(0, 8);
    return 'msg-$author-$_messageCounter';
  }

  /// Compute the [DeliveryState] of message [messageId] from the full set of
  /// [events] (across sender, recipient, and relays).
  ///
  /// * `MESSAGE_READ` receipt present -> [DeliveryState.read];
  /// * `MESSAGE_DELIVERED` receipt present -> [DeliveryState.delivered];
  /// * otherwise [DeliveryState.propagating] when [hasRoute] (the sent event is
  ///   in flight), else [DeliveryState.queued].
  static DeliveryState deliveryState(
    String messageId,
    List<SignedEvent> events, {
    bool hasRoute = true,
  }) {
    bool sent = false;
    bool delivered = false;
    bool read = false;
    for (final SignedEvent e in events) {
      switch (e.header.type) {
        case EventType.EVENT_TYPE_MESSAGE_SENT:
          if (MessageBody.fromBuffer(e.body).messageId == messageId) {
            sent = true;
          }
          break;
        case EventType.EVENT_TYPE_MESSAGE_DELIVERED:
          if (ReceiptBody.fromBuffer(e.body).messageId == messageId) {
            delivered = true;
          }
          break;
        case EventType.EVENT_TYPE_MESSAGE_READ:
          if (ReceiptBody.fromBuffer(e.body).messageId == messageId) {
            read = true;
          }
          break;
        default:
          break;
      }
    }
    if (read) return DeliveryState.read;
    if (delivered) return DeliveryState.delivered;
    if (sent && hasRoute) return DeliveryState.propagating;
    return DeliveryState.queued;
  }
}

/// Group messaging over the event log for restricted / mission channels.
///
/// Wraps a [GroupSecureSession]: `sendGroup` encrypts with the member's
/// sender-key chain and wraps the ciphertext in a `MESSAGE_SENT` event tagged
/// with the current `groupEpoch`; `receiveGroup` decrypts a peer's group
/// message. A membership change rotates the epoch (via
/// [GroupMessageFlow.rotateEpoch]) so a removed member — holding only the old
/// epoch's sender keys — cannot read any post-rotation message.
class GroupMessageFlow {
  GroupMessageFlow({
    required this.selfKeyPair,
    required this.clock,
    required this.channelId,
    required this.group,
    required int epoch,
    EventFactory? factory,
  })  : _epoch = epoch,
        _factory = factory ?? EventFactory();

  final KeyPairData selfKeyPair;
  final LamportClock clock;
  final String channelId;
  final GroupSecureSession group;
  final EventFactory _factory;

  int _epoch;
  int _messageCounter = 0;

  int get epoch => _epoch;

  /// Create a signed `CHANNEL_CREATED` event for a restricted/mission channel.
  Future<SignedEvent> createChannel({
    required ChannelType type,
    required String name,
    required List<List<int>> initialMembers,
  }) {
    final body = ChannelCreatedBody(
      channelId: channelId,
      type: type,
      name: name,
      initialMembers: initialMembers,
    );
    return _factory.buildFromMessage(
      keyPair: selfKeyPair,
      clock: clock,
      type: EventType.EVENT_TYPE_CHANNEL_CREATED,
      body: body,
    );
  }

  /// Create a signed `CHANNEL_MEMBERSHIP` event; callers pass the new [epoch]
  /// after a removal so the event records the rotation.
  Future<SignedEvent> membershipChange({
    List<List<int>> added = const <List<int>>[],
    List<List<int>> removed = const <List<int>>[],
    required int epoch,
  }) {
    final body = ChannelMembershipBody(
      channelId: channelId,
      added: added,
      removed: removed,
      epoch: Int64(epoch),
    );
    return _factory.buildFromMessage(
      keyPair: selfKeyPair,
      clock: clock,
      type: EventType.EVENT_TYPE_CHANNEL_MEMBERSHIP,
      body: body,
    );
  }

  /// Encrypt [plaintext] for the group and emit a `MESSAGE_SENT` carrying the
  /// current epoch.
  Future<SentMessage> sendGroup({
    required String plaintext,
    String? messageId,
    Priority priority = Priority.PRIORITY_NORMAL,
  }) async {
    final String id = messageId ?? _nextMessageId();
    final Uint8List ciphertext = await group.encryptText(plaintext);
    final body = MessageBody(
      messageId: id,
      channelId: channelId,
      ciphertext: ciphertext,
      groupEpoch: _epoch,
      priority: priority,
    );
    final SignedEvent event = await _factory.buildFromMessage(
      keyPair: selfKeyPair,
      clock: clock,
      type: EventType.EVENT_TYPE_MESSAGE_SENT,
      body: body,
    );
    return SentMessage(event: event, messageId: id);
  }

  /// Decrypt a group `MESSAGE_SENT` [event] authored by [senderName].
  Future<String?> receiveGroup(
    SignedEvent event, {
    required String senderName,
    int senderDeviceId = 1,
  }) async {
    if (event.header.type != EventType.EVENT_TYPE_MESSAGE_SENT) return null;
    if (!await _factory.verifyEvent(event)) return null;
    final MessageBody body = MessageBody.fromBuffer(event.body);
    if (body.channelId != channelId) return null;
    return group.decryptText(
      senderName: senderName,
      ciphertext: Uint8List.fromList(body.ciphertext),
      senderDeviceId: senderDeviceId,
    );
  }

  /// Advance the local epoch (call after a membership removal). Delegates to
  /// [GroupSecureSession.rotateEpoch]; remaining members must re-distribute
  /// their sender keys for the new epoch.
  void rotateEpoch(String baseGroupId, int newEpoch) {
    _epoch = newEpoch;
    group.rotateEpoch(baseGroupId, newEpoch);
  }

  String _nextMessageId() {
    _messageCounter++;
    return '$channelId-e$_epoch-$_messageCounter';
  }
}
