import 'dart:convert';
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

/// 1:1 end-to-end encrypted session facade over libsignal's X3DH +
/// Double Ratchet.
///
/// Security properties inherited from the Signal protocol:
///  * **authentication** — identity keys bound into the handshake,
///  * **forward secrecy** — ratchet advances per message,
///  * **post-compromise recovery** — DH ratchet heals after key exposure,
///  * **replay protection** — message counters reject duplicates,
///  * **offline recipient** — X3DH via published prekey bundle.
///
/// Wire framing: [encrypt] returns `[typeTag][libsignal serialized bytes]`.
/// The 1-byte tag distinguishes a [PreKeySignalMessage] (the first message,
/// which carries the X3DH handshake) from an ordinary [SignalMessage] so the
/// peer can re-hydrate the right type in [decrypt].
/// Raised on malformed or unroutable ciphertext in [SecureSession].
class SecureSessionException implements Exception {
  const SecureSessionException(this.message);

  final String message;

  @override
  String toString() => 'SecureSessionException: $message';
}

class SecureSession {
  SecureSession._(this._cipher, this._remoteAddress);

  final SessionCipher _cipher;
  final SignalProtocolAddress _remoteAddress;

  /// Establish an *outbound* session toward [remoteAddress] from [remoteBundle]
  /// (the peer's published prekey bundle). Runs the X3DH handshake.
  static Future<SecureSession> initiate({
    required SignalProtocolStore localStore,
    required SignalProtocolAddress remoteAddress,
    required PreKeyBundle remoteBundle,
  }) async {
    final builder = SessionBuilder.fromSignalStore(localStore, remoteAddress);
    await builder.processPreKeyBundle(remoteBundle);
    final cipher = SessionCipher.fromStore(localStore, remoteAddress);
    return SecureSession._(cipher, remoteAddress);
  }

  /// Build a session facade with no prior handshake. The first inbound message
  /// (a [PreKeySignalMessage]) will complete the X3DH handshake automatically
  /// during [decrypt].
  static SecureSession forRemote({
    required SignalProtocolStore localStore,
    required SignalProtocolAddress remoteAddress,
  }) {
    final cipher = SessionCipher.fromStore(localStore, remoteAddress);
    return SecureSession._(cipher, remoteAddress);
  }

  SignalProtocolAddress get remoteAddress => _remoteAddress;

  /// Encrypt [plaintext], returning self-describing ciphertext bytes.
  Future<Uint8List> encrypt(List<int> plaintext) async {
    final message = await _cipher.encrypt(
      Uint8List.fromList(utf8OrRaw(plaintext)),
    );
    final serialized = message.serialize();
    final framed = Uint8List(serialized.length + 1)
      ..[0] = message.getType()
      ..setRange(1, serialized.length + 1, serialized);
    return framed;
  }

  /// Encrypt a UTF-8 [text] convenience wrapper.
  Future<Uint8List> encryptText(String text) => encrypt(utf8.encode(text));

  /// Decrypt ciphertext produced by a peer's [encrypt].
  Future<Uint8List> decrypt(Uint8List ciphertext) async {
    if (ciphertext.isEmpty) {
      throw const SecureSessionException('Empty ciphertext');
    }
    final type = ciphertext[0];
    final body = Uint8List.fromList(ciphertext.sublist(1));
    switch (type) {
      case CiphertextMessage.prekeyType:
        final msg = PreKeySignalMessage(body);
        return _cipher.decrypt(msg);
      case CiphertextMessage.whisperType:
        final msg = SignalMessage.fromSerialized(body);
        return _cipher.decryptFromSignal(msg);
      default:
        throw SecureSessionException('Unknown message type: $type');
    }
  }

  /// Decrypt and decode a UTF-8 string.
  Future<String> decryptText(Uint8List ciphertext) async =>
      utf8.decode(await decrypt(ciphertext));
}

/// Group end-to-end encryption facade using libsignal's Sender-Key scheme.
///
/// Each member has an own sender-key chain. A member distributes its sender
/// key once (a [SenderKeyDistributionMessageWrapper]); peers [processDistribution]
/// it, then everyone encrypts/decrypts with [encrypt]/[decrypt].
///
/// **Membership rotation / post-removal secrecy:** when a member is removed the
/// group MUST move to a new epoch. [rotateEpoch] produces a fresh [groupId]
/// (new sender-key state) so a removed member — who only holds the previous
/// epoch's sender keys — cannot decrypt any future-epoch message. Remaining
/// members re-distribute their sender keys for the new epoch.
class GroupSecureSession {
  GroupSecureSession._(
    this._store,
    this._builder,
    this._groupId,
    this._selfName,
    this._selfDeviceId,
  );

  final SenderKeyStore _store;
  final GroupSessionBuilder _builder;
  String _groupId;
  final String _selfName;
  final int _selfDeviceId;

  /// Create a group session for the local member identified by
  /// [selfName]/[selfDeviceId] within logical group [groupId]/[epoch].
  static GroupSecureSession create({
    required String groupId,
    required String selfName,
    int selfDeviceId = 1,
    int epoch = 0,
    SenderKeyStore? store,
  }) {
    final senderKeyStore = store ?? InMemorySenderKeyStore();
    final builder = GroupSessionBuilder(senderKeyStore);
    return GroupSecureSession._(
      senderKeyStore,
      builder,
      _epochGroupId(groupId, epoch),
      selfName,
      selfDeviceId,
    );
  }

  /// The current epoch-scoped group id used for sender-key state.
  String get groupId => _groupId;

  SenderKeyName get _selfSenderKeyName => SenderKeyName(
        _groupId,
        SignalProtocolAddress(_selfName, _selfDeviceId),
      );

  /// Create (or fetch) this member's sender-key distribution message to hand
  /// to every other member so they can decrypt this member's messages.
  Future<SenderKeyDistributionMessageWrapper> createDistribution() {
    return _builder.create(_selfSenderKeyName);
  }

  /// Process a distribution message received from [senderName]/[senderDeviceId]
  /// so this member can decrypt that sender's group messages.
  Future<void> processDistribution({
    required String senderName,
    required SenderKeyDistributionMessageWrapper distribution,
    int senderDeviceId = 1,
  }) async {
    final name = SenderKeyName(
      _groupId,
      SignalProtocolAddress(senderName, senderDeviceId),
    );
    await _builder.process(name, distribution);
  }

  /// Encrypt [plaintext] as this member, returning serialized ciphertext.
  Future<Uint8List> encrypt(List<int> plaintext) {
    final cipher = GroupCipher(_store, _selfSenderKeyName);
    return cipher.encrypt(Uint8List.fromList(utf8OrRaw(plaintext)));
  }

  /// Encrypt a UTF-8 string convenience wrapper.
  Future<Uint8List> encryptText(String text) => encrypt(utf8.encode(text));

  /// Decrypt [ciphertext] that was produced by [senderName]/[senderDeviceId].
  Future<Uint8List> decrypt({
    required String senderName,
    required Uint8List ciphertext,
    int senderDeviceId = 1,
  }) {
    final name = SenderKeyName(
      _groupId,
      SignalProtocolAddress(senderName, senderDeviceId),
    );
    final cipher = GroupCipher(_store, name);
    return cipher.decrypt(ciphertext);
  }

  /// Decrypt and decode a UTF-8 string convenience wrapper.
  Future<String> decryptText({
    required String senderName,
    required Uint8List ciphertext,
    int senderDeviceId = 1,
  }) async =>
      utf8.decode(await decrypt(
        senderName: senderName,
        ciphertext: ciphertext,
        senderDeviceId: senderDeviceId,
      ));

  /// Advance to a new epoch (call after adding/removing a member). The local
  /// group id switches to the new epoch, discarding all prior sender-key state
  /// visibility; every remaining member must re-run [createDistribution] and
  /// exchange the new distributions. Removed members, lacking the new epoch's
  /// keys, cannot decrypt future messages.
  void rotateEpoch(String baseGroupId, int newEpoch) {
    _groupId = _epochGroupId(baseGroupId, newEpoch);
  }

  static String _epochGroupId(String groupId, int epoch) => '$groupId#$epoch';
}

/// Accept raw byte lists without re-encoding; identity helper used so callers
/// can pass either UTF-8-encoded bytes or arbitrary payloads.
List<int> utf8OrRaw(List<int> input) => input;
