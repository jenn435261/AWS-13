import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart' as cvt;

/// A message attachment reference carried INSIDE the end-to-end-encrypted
/// [MessagePayload] (spec §6).
///
/// The actual file is uploaded to a content-addressed blob store as ciphertext;
/// only this small descriptor travels in the Signal ciphertext. It carries the
/// random symmetric [key] used to AES-GCM encrypt the blob, so a relay that
/// holds the blob still cannot read it (it never sees this descriptor). On
/// receipt the recipient downloads the blob by [sha256], decrypts with [key],
/// and MUST verify the sha256 of the ciphertext before displaying.
class Attachment {
  Attachment({
    required this.sha256,
    required this.size,
    required this.mime,
    required Uint8List key,
    Uint8List? thumbnail,
    this.durationMs = 0,
    this.width = 0,
    this.height = 0,
  })  : key = Uint8List.fromList(key),
        thumbnail = thumbnail == null ? null : Uint8List.fromList(thumbnail);

  /// Lowercase hex SHA-256 of the CIPHERTEXT (the content address in the blob
  /// store).
  final String sha256;

  /// Ciphertext size in bytes.
  final int size;

  /// MIME type of the plaintext (e.g. image/jpeg, audio/aac).
  final String mime;

  /// Random 256-bit AES-GCM key for this blob. Secret; never logged.
  final Uint8List key;

  /// Optional tiny inline preview (<=8KB), already small enough to ride inside
  /// the E2E message so a photo shows instantly without a blob fetch.
  final Uint8List? thumbnail;

  /// Audio duration in milliseconds (0 for photos).
  final int durationMs;

  /// Photo pixel dimensions (0 when unknown / audio).
  final int width;
  final int height;

  bool get isImage => mime.startsWith('image/');
  bool get isAudio => mime.startsWith('audio/');

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sha256': sha256,
        'size': size,
        'mime': mime,
        'key': cvt.hex.encode(key),
        if (thumbnail != null) 'thumb': base64.encode(thumbnail!),
        if (durationMs > 0) 'dur': durationMs,
        if (width > 0) 'w': width,
        if (height > 0) 'h': height,
      };

  static Attachment fromJson(Map<String, dynamic> j) => Attachment(
        sha256: j['sha256'] as String,
        size: (j['size'] as num).toInt(),
        mime: j['mime'] as String,
        key: Uint8List.fromList(cvt.hex.decode(j['key'] as String)),
        thumbnail: j['thumb'] == null
            ? null
            : Uint8List.fromList(base64.decode(j['thumb'] as String)),
        durationMs: (j['dur'] as num?)?.toInt() ?? 0,
        width: (j['w'] as num?)?.toInt() ?? 0,
        height: (j['h'] as num?)?.toInt() ?? 0,
      );
}

/// The decrypted payload of a direct message (spec §6).
///
/// This is what is serialized to bytes, encrypted with the Signal session, and
/// placed in `MessageBody.ciphertext`. Keeping text and attachment descriptors
/// in one E2E-encrypted envelope means the blob key never leaves the encrypted
/// channel — relays only ever see opaque ciphertext for both the message and
/// the blob.
class MessagePayload {
  MessagePayload({
    this.kind = 'text',
    this.text = '',
    List<Attachment>? attachments,
  }) : attachments = attachments ?? const <Attachment>[];

  /// 'text' | 'photo' | 'audio' | 'mixed'.
  final String kind;
  final String text;
  final List<Attachment> attachments;

  Uint8List encode() {
    final map = <String, dynamic>{
      'kind': kind,
      'text': text,
      'att': attachments.map((a) => a.toJson()).toList(),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  /// Decode a payload. Falls back to treating raw bytes as plain UTF-8 text
  /// when they are not a MessagePayload JSON envelope (back-compat with the
  /// original text-only wire form).
  static MessagePayload decode(List<int> bytes) {
    try {
      final obj = jsonDecode(utf8.decode(bytes));
      if (obj is Map && obj.containsKey('kind')) {
        final atts = <Attachment>[];
        final raw = obj['att'];
        if (raw is List) {
          for (final a in raw) {
            if (a is Map) {
              atts.add(Attachment.fromJson(a.cast<String, dynamic>()));
            }
          }
        }
        return MessagePayload(
          kind: obj['kind'] as String? ?? 'text',
          text: obj['text'] as String? ?? '',
          attachments: atts,
        );
      }
    } catch (_) {
      // Not a JSON envelope — treat as legacy plain text below.
    }
    return MessagePayload(text: utf8.decode(bytes, allowMalformed: true));
  }
}
