import 'dart:convert';

import 'package:resilience/core/signing.dart';
import 'package:resilience/nodes/package_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds the signed-manifest JSON body exactly as the node serves it: the
/// detached Ed25519 signature is over the manifest's canonical bytes (compact
/// JSON, entries sorted by kind then name). This mirrors
/// node/internal/packages.SignManifest so the Dart verifier is exercised
/// against the real wire shape.
Future<Map<String, dynamic>> buildSignedManifest(
  Signer signer,
  KeyPairData key,
  List<ManifestEntry> entries, {
  int generatedMs = 1700000000000,
}) async {
  final manifest = PackageManifest(
    version: 1,
    generatedMs: generatedMs,
    entries: entries,
  );
  final sig = await signer.sign(key, manifest.canonicalBytes());
  // Reconstruct the manifest JSON in the same order used for canonical bytes.
  final sorted = [...entries]..sort((a, b) {
      final k = a.kind.compareTo(b.kind);
      return k != 0 ? k : a.name.compareTo(b.name);
    });
  return {
    'manifest': {
      'version': 1,
      'generated_ms': generatedMs,
      'entries': [
        for (final e in sorted)
          {
            'kind': e.kind,
            'name': e.name,
            'path': e.path,
            'size_bytes': e.sizeBytes,
            'sha256': e.sha256,
          }
      ],
    },
    'public_key': _hex(key.publicKey),
    'signature': _hex(sig),
    'algorithm': 'ed25519',
  };
}

String _hex(List<int> b) =>
    b.map((x) => (x & 0xff).toRadixString(16).padLeft(2, '0')).join();

void main() {
  final entry = ManifestEntry(
    kind: 'map',
    name: 'bay.pmtiles',
    path: '/node/v1/map/bay.pmtiles',
    sizeBytes: 10,
    sha256: 'aa' * 32,
  );

  test('verifies a correctly signed manifest against the trusted root',
      () async {
    final signer = Signer();
    final key = await signer.generateKeyPair();
    final body = await buildSignedManifest(signer, key, [entry]);

    final res = await verifySignedManifest(body, _hex(key.publicKey));
    expect(res.ok, isTrue);
    expect(res.manifest!.entries.single.sha256, entry.sha256);
    expect(res.manifest!.entryForPath('/node/v1/map/bay.pmtiles'), isNotNull);
  });

  test('rejects a manifest signed by an untrusted key', () async {
    final signer = Signer();
    final key = await signer.generateKeyPair();
    final other = await signer.generateKeyPair();
    final body = await buildSignedManifest(signer, key, [entry]);

    final res = await verifySignedManifest(body, _hex(other.publicKey));
    expect(res.status, ManifestVerify.untrustedKey);
    expect(res.manifest, isNull);
  });

  test('rejects a manifest whose body was tampered after signing', () async {
    final signer = Signer();
    final key = await signer.generateKeyPair();
    final body = await buildSignedManifest(signer, key, [entry]);
    // Tamper with the checksum in the body (the attack this defends against).
    (body['manifest']['entries'] as List)[0]['sha256'] = 'bb' * 32;

    final res = await verifySignedManifest(body, _hex(key.publicKey));
    expect(res.status, ManifestVerify.badSignature);
  });

  test('rejects an unsupported algorithm', () async {
    final signer = Signer();
    final key = await signer.generateKeyPair();
    final body = await buildSignedManifest(signer, key, [entry]);
    body['algorithm'] = 'rsa';
    final res = await verifySignedManifest(body, _hex(key.publicKey));
    expect(res.status, ManifestVerify.malformed);
  });

  test('canonical bytes are stable and entry-order independent', () async {
    const a = ManifestEntry(
        kind: 'map', name: 'a.pmtiles', path: '/p/a', sizeBytes: 1, sha256: '00');
    const b = ManifestEntry(
        kind: 'app', name: 'z.apk', path: '/p/z', sizeBytes: 2, sha256: '11');
    final m1 = PackageManifest(version: 1, generatedMs: 5, entries: [a, b]);
    final m2 = PackageManifest(version: 1, generatedMs: 5, entries: [b, a]);
    expect(utf8.decode(m1.canonicalBytes()),
        equals(utf8.decode(m2.canonicalBytes())));
    // Sorted order puts "app" before "map".
    expect(utf8.decode(m1.canonicalBytes()).indexOf('z.apk'),
        lessThan(utf8.decode(m1.canonicalBytes()).indexOf('a.pmtiles')));
  });

  test('canonical bytes keep literal & < > (match Go, no HTML escaping)',
      () async {
    // A literal '&' is ordinary in filenames; '<' and '>' are the other runes
    // Go's default json.Marshal would escape. The Dart canonicalizer must emit
    // them literally so the preimage matches Go's SetEscapeHTML(false) output.
    const special = ManifestEntry(
      kind: 'map',
      name: 'rescue & relief <east>.pmtiles',
      path: '/node/v1/map/rescue & relief <east>.pmtiles',
      sizeBytes: 3,
      sha256: '00',
    );
    final m = PackageManifest(version: 1, generatedMs: 5, entries: [special]);
    final canonical = utf8.decode(m.canonicalBytes());
    expect(canonical.contains('&'), isTrue);
    expect(canonical.contains('<'), isTrue);
    expect(canonical.contains('>'), isTrue);
    expect(canonical.contains(r'\u0026'), isFalse);
    expect(canonical.contains(r'\u003c'), isFalse);
    expect(canonical.contains(r'\u003e'), isFalse);
  });

  test('verifies a signed manifest whose path contains & < >', () async {
    // Cross-language regression guard for the canonicalization gap: an entry
    // with special characters must still verify (not report badSignature).
    final special = ManifestEntry(
      kind: 'map',
      name: 'a & b <c>.pmtiles',
      path: '/node/v1/map/a & b <c>.pmtiles',
      sizeBytes: 7,
      sha256: 'aa' * 32,
    );
    final signer = Signer();
    final key = await signer.generateKeyPair();
    final body = await buildSignedManifest(signer, key, [special]);

    final res = await verifySignedManifest(body, _hex(key.publicKey));
    expect(res.ok, isTrue);
    expect(res.manifest!.entryForPath('/node/v1/map/a & b <c>.pmtiles'),
        isNotNull);
  });

  test('sha256Hex matches a known vector', () async {
    // echo -n "abc" | sha256sum
    final got = await sha256Hex(utf8.encode('abc'));
    expect(got,
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });
}
