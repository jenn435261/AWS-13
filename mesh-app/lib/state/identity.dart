import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../models/event.dart';

/// This phone's cryptographic identity (Spec sections 11 and 53).
/// The Resilience ID comes from the public key, never from a phone number.
///
/// DEMO: the key pair lives in memory, so it changes on every launch. On a
/// device it must be kept in the iOS Keychain / Android Keystore, and the
/// private key never leaves the phone.
class Identity {
  Identity._(this._keyPair, this.publicKey, this.resilienceId);

  static final _ed25519 = Ed25519();

  final SimpleKeyPair _keyPair;
  final List<int> publicKey;

  /// 16 hex characters, shown in groups of four.
  final String resilienceId;

  static Future<Identity> generate() async {
    final pair = await _ed25519.newKeyPair();
    final public = (await pair.extractPublicKey()).bytes;
    final digest = await Sha256().hash(public);
    return Identity._(pair, public, _hex(digest.bytes).substring(0, 16));
  }

  String get displayId => [
        for (var i = 0; i < resilienceId.length; i += 4)
          resilienceId.substring(i, i + 4),
      ].join(' ');

  /// What another phone reads from this phone's QR code: who it is and the
  /// public key, nothing private.
  String qrPayload(String name) => Uri(
        scheme: 'resilience',
        host: 'contact',
        queryParameters: {
          'id': resilienceId,
          'name': name,
          'key': base64Url.encode(publicKey),
        },
      ).toString();

  Future<SignedEvent> sign(String id, EventType type, String subject) async {
    final at = DateTime.now();
    final text = SignedEvent.signedText(id, type, subject, at, resilienceId);
    final signature = await _ed25519.sign(utf8.encode(text), keyPair: _keyPair);
    return SignedEvent(
      id: id,
      type: type,
      subject: subject,
      at: at,
      author: resilienceId,
      signature: _hex(signature.bytes),
    );
  }

  /// Checks that [event] was signed by this identity and not changed since.
  /// Returns false, never throws, for a malformed or foreign signature.
  Future<bool> verify(SignedEvent event) async {
    if (event.author != resilienceId) return false;
    final bytes = _unhex(event.signature);
    if (bytes == null || bytes.length != 64) return false;
    final text = SignedEvent.signedText(
      event.id,
      event.type,
      event.subject,
      event.at,
      event.author,
    );
    return _ed25519.verify(
      utf8.encode(text),
      signature: Signature(
        bytes,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      ),
    );
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int>? _unhex(String hex) {
    if (!RegExp(r'^(?:[0-9a-f]{2})*$').hasMatch(hex)) return null;
    return [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];
  }
}

/// Reads a contact from a scanned QR code, or null if it isn't one.
({String id, String name})? parseContactQr(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'resilience' || uri.host != 'contact') {
    return null;
  }
  final id = uri.queryParameters['id'] ?? '';
  final name = uri.queryParameters['name'] ?? '';
  if (!RegExp(r'^[0-9a-f]{16}$').hasMatch(id) || name.trim().isEmpty) return null;
  return (id: id, name: name.trim());
}

/// Accepts a typed Resilience ID with or without spaces.
String? normalizeResilienceId(String typed) {
  final id = typed.replaceAll(RegExp(r'\s'), '').toLowerCase();
  return RegExp(r'^[0-9a-f]{16}$').hasMatch(id) ? id : null;
}
