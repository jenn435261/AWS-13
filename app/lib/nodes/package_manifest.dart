import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';

import '../core/signing.dart';

/// One artifact's integrity record inside a signed package manifest: the
/// node-relative path plus the SHA-256 checksum a client must verify after
/// downloading the bytes (over any channel, including a resumed Range fetch).
class ManifestEntry {
  final String kind;
  final String name;
  final String path;
  final int sizeBytes;
  final String sha256; // lowercase hex

  const ManifestEntry({
    required this.kind,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.sha256,
  });

  static ManifestEntry? fromJson(Map<String, dynamic> j) {
    final name = j['name'], path = j['path'], sha = j['sha256'];
    if (name is! String || path is! String || sha is! String) return null;
    return ManifestEntry(
      kind: j['kind'] as String? ?? 'other',
      name: name,
      path: path,
      sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
      sha256: sha.toLowerCase(),
    );
  }

  /// Canonical map in the exact field order the node signs over. Keep this in
  /// lockstep with Go's packages.ManifestEntry struct field order.
  Map<String, dynamic> _canonical() => {
        'kind': kind,
        'name': name,
        'path': path,
        'size_bytes': sizeBytes,
        'sha256': sha256,
      };
}

/// A verified package manifest: the node's description of exactly what it
/// serves, with a per-file checksum. Only trust a manifest returned by
/// [verifySignedManifest]; never read checksums from an unverified manifest.
class PackageManifest {
  final int version;
  final int generatedMs;
  final List<ManifestEntry> entries;
  const PackageManifest(
      {required this.version,
      required this.generatedMs,
      required this.entries});

  /// Returns the entry whose node-relative [path] matches, or null.
  ManifestEntry? entryForPath(String path) {
    for (final e in entries) {
      if (e.path == path) return e;
    }
    return null;
  }

  /// Canonical, deterministic bytes that match Go's
  /// packages.Manifest.CanonicalBytes (compact JSON, entries sorted by
  /// kind then name, struct field order preserved). This is what the detached
  /// signature covers.
  List<int> canonicalBytes() {
    final sorted = [...entries];
    sorted.sort((a, b) {
      final k = a.kind.compareTo(b.kind);
      return k != 0 ? k : a.name.compareTo(b.name);
    });
    final map = {
      'version': version,
      'generated_ms': generatedMs,
      'entries': [for (final e in sorted) e._canonical()],
    };
    // jsonEncode emits compact JSON with no spaces and preserves map insertion
    // order. It does NOT HTML-escape '<', '>' or '&'; the Go signer matches
    // this by calling json.Encoder.SetEscapeHTML(false), so the two canonical
    // byte strings agree even when a name/path contains one of those runes
    // (e.g. a literal '&' in a filename).
    return utf8.encode(jsonEncode(map));
  }
}

/// Outcome of verifying a signed manifest.
enum ManifestVerify {
  ok,

  /// The signing key is not the trusted root the client expects.
  untrustedKey,

  /// The detached signature does not verify.
  badSignature,

  /// The payload was malformed or used an unsupported algorithm.
  malformed,
}

/// The result of [verifySignedManifest]: the status and, when [ManifestVerify.ok],
/// the trusted [manifest].
class SignedManifestResult {
  final ManifestVerify status;
  final PackageManifest? manifest;
  const SignedManifestResult(this.status, [this.manifest]);
  bool get ok => status == ManifestVerify.ok;
}

/// Verifies a node-served signed manifest (the JSON body of
/// GET /node/v1/manifest) fail-closed against [trustedRootHex] (lowercase hex
/// Ed25519 public key). It returns the verified [PackageManifest] only when the
/// algorithm is supported, the embedded key equals the trusted root, and the
/// detached signature verifies over the manifest's canonical bytes.
///
/// A caller MUST call this before reading any checksum; a download is trusted
/// only when its SHA-256 matches the entry in a verified manifest.
Future<SignedManifestResult> verifySignedManifest(
  Map<String, dynamic> body,
  String trustedRootHex, {
  Signer? signer,
}) async {
  if (body['algorithm'] != 'ed25519') {
    return const SignedManifestResult(ManifestVerify.malformed);
  }
  final pubHex = (body['public_key'] as String?)?.toLowerCase();
  final sigHex = (body['signature'] as String?)?.toLowerCase();
  final mj = body['manifest'];
  if (pubHex == null || sigHex == null || mj is! Map<String, dynamic>) {
    return const SignedManifestResult(ManifestVerify.malformed);
  }
  if (pubHex != trustedRootHex.toLowerCase()) {
    return const SignedManifestResult(ManifestVerify.untrustedKey);
  }

  final entries = ((mj['entries'] as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(ManifestEntry.fromJson)
      .whereType<ManifestEntry>()
      .toList();
  final manifest = PackageManifest(
    version: (mj['version'] as num?)?.toInt() ?? 0,
    generatedMs: (mj['generated_ms'] as num?)?.toInt() ?? 0,
    entries: entries,
  );

  final pub = _hexDecode(pubHex);
  final sig = _hexDecode(sigHex);
  if (pub == null || sig == null) {
    return const SignedManifestResult(ManifestVerify.malformed);
  }

  final ok = await (signer ?? Signer())
      .verify(pub, manifest.canonicalBytes(), sig);
  if (!ok) return const SignedManifestResult(ManifestVerify.badSignature);
  return SignedManifestResult(ManifestVerify.ok, manifest);
}

const DartSha256 _dartSha256 = DartSha256();

/// Lowercase hex SHA-256 of [bytes]. Used to verify a downloaded file against
/// the checksum in a verified manifest.
Future<String> sha256Hex(List<int> bytes) async {
  final hash = await _dartSha256.hash(bytes);
  return _hexEncode(hash.bytes);
}

String _hexEncode(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write((b & 0xff).toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

Uint8List? _hexDecode(String hex) {
  if (hex.length.isOdd) return null;
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    final byte = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    if (byte == null) return null;
    out[i] = byte;
  }
  return out;
}
