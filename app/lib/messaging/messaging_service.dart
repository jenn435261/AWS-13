import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../core/event_factory.dart';
import '../core/event_store.dart';
import '../core/lamport_clock.dart';
import '../core/signing.dart';
import '../db/json_store.dart';
import '../db/signal_dao.dart';
import '../gen/resilience/v1/event.pb.dart';
import 'blob_transport.dart';
import 'drift_signal_store.dart';
import 'message_flow.dart';
import 'message_payload.dart';
import 'secure_session.dart';
import 'signal_keys.dart';

/// A decrypted conversation entry for the UI.
class DirectMessage {
  DirectMessage({
    required this.messageId,
    required this.fromMe,
    required this.timestampMs,
    required this.lamport,
    required this.deliveryState,
    required this.payload,
  });

  final String messageId;
  final bool fromMe;
  final int timestampMs;
  final int lamport;
  final DeliveryState deliveryState;
  final MessagePayload payload;
}

/// Ties the durable Signal store, the event log, and the sync client together
/// so the Messages screen really works end to end.
///
/// Prekey distribution rides the existing sync path: a device publishes its
/// prekey bundle as a signed `PREKEY_BUNDLE` event (so it flows over the
/// FEAT-002 sync client with no new endpoint), and a chat is started by looking
/// up the contact's most recent `PREKEY_BUNDLE` event folded from the log and
/// running X3DH. Messages are `MESSAGE_SENT` events carrying Signal ciphertext.
class MessagingService {
  MessagingService({
    required this.store,
    required this.signalDao,
    required this.factory,
    required this.clock,
    required this.selfKeyPair,
    required this.blob,
    required this.mirrorStore,
  });

  final EventStore store;
  final SignalDao signalDao;
  final EventFactory factory;
  final LamportClock clock;
  final KeyPairData selfKeyPair;
  final BlobTransport blob;

  /// Durable mirror of our own outbound plaintext, keyed by message id. We
  /// cannot decrypt our own ratchet ciphertext, so we keep a local copy to show
  /// our sent bubbles. It never leaves the device.
  final JsonStore mirrorStore;

  DriftSignalProtocolStore? _signal;

  /// Load the durable Signal store (generating device keys on first run).
  Future<DriftSignalProtocolStore> _signalStore() async {
    return _signal ??= await SignalKeys.loadDurableStore(signalDao);
  }

  /// Ensure our prekey bundle is published as a `PREKEY_BUNDLE` event. Idempotent
  /// best-effort: if we have already published one we do nothing.
  Future<void> publishMyBundle() async {
    final existing = await _latestBundleBody(selfKeyPair.publicKey);
    if (existing != null) return;

    final signal = await _signalStore();
    final identity = await signal.getIdentityKeyPair();
    final reg = await signal.getLocalRegistrationId();
    final signed = await signal.loadSignedPreKey(0);
    PreKeyRecord? oneTime;
    try {
      oneTime = await signal.loadPreKey(1);
    } catch (_) {
      oneTime = null;
    }
    final body = PrekeyBundleBody(
      identityPubkey: identity.getPublicKey().serialize(),
      registrationId: reg,
      signedPrekeyId: signed.id,
      signedPrekeyPub: signed.getKeyPair().publicKey.serialize(),
      signedPrekeySig: signed.signature,
      prekeyId: oneTime?.id ?? 0,
      prekeyPub: oneTime?.getKeyPair().publicKey.serialize() ?? <int>[],
    );
    final event = await factory.buildFromMessage(
      keyPair: selfKeyPair,
      clock: clock,
      type: EventType.EVENT_TYPE_PREKEY_BUNDLE,
      body: body,
    );
    await store.apply(event);
  }

  /// The most recent published prekey bundle for [authorPubkey], or null.
  Future<PrekeyBundleBody?> _latestBundleBody(List<int> authorPubkey) async {
    final want = Uint8List.fromList(authorPubkey);
    final all = await store.dao.allEvents();
    PrekeyBundleBody? latest;
    int latestLamport = -1;
    for (final e in all) {
      if (e.header.type != EventType.EVENT_TYPE_PREKEY_BUNDLE) continue;
      if (!_bytesEqual(e.header.authorPubkey, want)) continue;
      final l = e.header.lamport.toInt();
      if (l > latestLamport) {
        latestLamport = l;
        latest = PrekeyBundleBody.fromBuffer(e.body);
      }
    }
    return latest;
  }

  /// Whether a session can be started with [contactPubkey] (their bundle is in
  /// the log).
  Future<bool> hasBundleFor(List<int> contactPubkey) async =>
      (await _latestBundleBody(contactPubkey)) != null;

  String _addrName(List<int> pubkey) => blobHex(pubkey);

  /// Build a [MessageFlow] toward [contactPubkey], establishing a session from
  /// their published bundle if one is not already present.
  Future<MessageFlow?> _flowFor(List<int> contactPubkey) async {
    final signal = await _signalStore();
    final remote = SignalProtocolAddress(_addrName(contactPubkey), 1);

    if (!await signal.containsSession(remote)) {
      final body = await _latestBundleBody(contactPubkey);
      if (body == null) return null; // no bundle yet; cannot start a session.
      final bundle = SignalKeys.preKeyBundleFromBody(body);
      final builder = SessionBuilder.fromSignalStore(signal, remote);
      await builder.processPreKeyBundle(bundle);
    }
    final session = SecureSessionForAddress(signal, remote);
    return MessageFlow(
      selfKeyPair: selfKeyPair,
      clock: clock,
      session: session.session,
      factory: factory,
    );
  }

  /// Send [payload] to [contactPubkey]: encrypt, store a MESSAGE_SENT event
  /// (applied through EventStore), and return the message id. The caller
  /// triggers a sync afterwards.
  Future<String?> send(
    List<int> contactPubkey,
    MessagePayload payload,
  ) async {
    final flow = await _flowFor(contactPubkey);
    if (flow == null) return null;
    final sent = await flow.sendPayload(
      recipientPubkey: contactPubkey,
      payload: payload,
    );
    await store.apply(sent.event);
    await mirrorSent(sent.messageId, payload);
    return sent.messageId;
  }

  /// Encrypt+upload an attachment and return its descriptor.
  Future<Attachment> uploadAttachment({
    required List<int> bytes,
    required String mime,
    Uint8List? thumbnail,
    int durationMs = 0,
    int width = 0,
    int height = 0,
  }) {
    return MessageFlow.attachBytes(
      blob: blob,
      plaintext: bytes,
      mime: mime,
      thumbnail: thumbnail,
      durationMs: durationMs,
      width: width,
      height: height,
    );
  }

  /// Fold the conversation with [contactPubkey] from the event log, decrypting
  /// our own and the contact's messages. Emits delivery receipts for newly-seen
  /// inbound messages (so the sender's state can advance).
  Future<List<DirectMessage>> conversation(List<int> contactPubkey) async {
    final signal = await _signalStore();
    final remote = SignalProtocolAddress(_addrName(contactPubkey), 1);
    final session = SecureSessionForAddress(signal, remote).session;
    final myHint = MessageFlow.recipientHintFor(selfKeyPair.publicKey);
    final theirHint = MessageFlow.recipientHintFor(contactPubkey);

    final all = await store.dao.allEvents();
    final mirrors = await _loadMirrors();
    final out = <DirectMessage>[];
    for (final e in all) {
      if (e.header.type != EventType.EVENT_TYPE_MESSAGE_SENT) continue;
      if (!await factory.verifyEvent(e)) continue;
      final body = MessageBody.fromBuffer(e.body);
      final fromMe = _bytesEqual(e.header.authorPubkey,
          Uint8List.fromList(selfKeyPair.publicKey));
      final isOutbound = fromMe && _hintEq(body.recipientHint, theirHint);
      final isInbound = !fromMe &&
          _bytesEqual(e.header.authorPubkey,
              Uint8List.fromList(contactPubkey)) &&
          _hintEq(body.recipientHint, myHint);
      if (!isOutbound && !isInbound) continue;

      MessagePayload? payload;
      if (isInbound) {
        try {
          final clear =
              await session.decrypt(Uint8List.fromList(body.ciphertext));
          payload = MessagePayload.decode(clear);
        } catch (_) {
          payload = null; // undecryptable (not shown as readable).
        }
      } else {
        // Outbound: we cannot decrypt our own ratchet ciphertext, so we show
        // the durable local mirror of what we composed.
        payload = mirrors[body.messageId];
      }

      out.add(DirectMessage(
        messageId: body.messageId,
        fromMe: fromMe,
        timestampMs: e.header.createdAtMs.toInt(),
        lamport: e.header.lamport.toInt(),
        deliveryState: MessageFlow.deliveryState(body.messageId, all),
        payload: payload ?? MessagePayload(text: ''),
      ));
    }
    out.sort((a, b) => a.lamport.compareTo(b.lamport));
    return out;
  }

  /// Fetch+decrypt+verify an attachment for display.
  Future<Uint8List> fetchAttachment(Attachment a) =>
      MessageFlow.fetchAttachment(blob: blob, attachment: a);

  /// Record what we composed so the outbound bubble shows real content (we
  /// cannot decrypt our own ratchet ciphertext). Persisted locally only.
  Future<void> mirrorSent(String messageId, MessagePayload payload) async {
    final j = <String, dynamic>{
      'kind': payload.kind,
      'text': payload.text,
      'att': payload.attachments.map((a) => a.toJson()).toList(),
    };
    await mirrorStore.put(messageId, {'id': messageId, 'payload': j});
  }

  Future<Map<String, MessagePayload>> _loadMirrors() async {
    final rows = await mirrorStore.all();
    final out = <String, MessagePayload>{};
    for (final r in rows) {
      final id = r['id'] as String?;
      final p = r['payload'];
      if (id == null || p is! Map) continue;
      final atts = <Attachment>[];
      final raw = p['att'];
      if (raw is List) {
        for (final a in raw) {
          if (a is Map) atts.add(Attachment.fromJson(a.cast<String, dynamic>()));
        }
      }
      out[id] = MessagePayload(
        kind: p['kind'] as String? ?? 'text',
        text: p['text'] as String? ?? '',
        attachments: atts,
      );
    }
    return out;
  }

  static bool _hintEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A thin wrapper exposing a [SecureSession] for a given address over a store.
class SecureSessionForAddress {
  SecureSessionForAddress(SignalProtocolStore store, SignalProtocolAddress addr)
      : session = SecureSession.forRemote(localStore: store, remoteAddress: addr);
  final SecureSession session;
}

/// Lowercase hex of [bytes] (used as a libsignal address name).
String blobHex(List<int> bytes) {
  const digits = '0123456789abcdef';
  final sb = StringBuffer();
  for (final b in bytes) {
    sb
      ..write(digits[(b >> 4) & 0xf])
      ..write(digits[b & 0xf]);
  }
  return sb.toString();
}
