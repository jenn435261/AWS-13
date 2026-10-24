import 'dart:convert';

import 'package:resilience/core/signing.dart';
import 'package:resilience/nodes/package_manifest.dart';
import 'package:resilience/packages/cloud_package_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _hex(List<int> b) =>
    b.map((x) => (x & 0xff).toRadixString(16).padLeft(2, '0')).join();

Future<Map<String, dynamic>> _signedBody(
    Signer signer, KeyPairData key, List<ManifestEntry> entries) async {
  final manifest =
      PackageManifest(version: 1, generatedMs: 1700000000000, entries: entries);
  final sig = await signer.sign(key, manifest.canonicalBytes());
  final sorted = [...entries]..sort((a, b) {
      final k = a.kind.compareTo(b.kind);
      return k != 0 ? k : a.name.compareTo(b.name);
    });
  return {
    'manifest': {
      'version': 1,
      'generated_ms': 1700000000000,
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

void main() {
  final entry = ManifestEntry(
    kind: 'map',
    name: 'bay.pmtiles',
    path: '/v1/packages/bay.pmtiles',
    sizeBytes: 100,
    sha256: 'aa' * 32,
  );

  test('fetchManifest verifies a cloud manifest against the trusted root',
      () async {
    final signer = Signer();
    final key = await signer.generateKeyPair();
    final body = await _signedBody(signer, key, [entry]);

    final mock = MockClient((req) async {
      expect(req.url.path, '/v1/packages/manifest');
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json'});
    });

    final client = CloudPackageClient.cloud(
      baseUrl: 'https://cloud.example',
      trustedRootHex: _hex(key.publicKey),
      client: mock,
    );
    final res = await client.fetchManifest();
    expect(res.ok, isTrue);
    expect(res.manifest!.entries.single.name, 'bay.pmtiles');
    // The download URL for the entry is absolute.
    expect(client.urlForEntry(res.manifest!.entries.single).toString(),
        'https://cloud.example/v1/packages/bay.pmtiles');
  });

  test('fetchManifest rejects a cloud manifest signed by the wrong key',
      () async {
    final signer = Signer();
    final key = await signer.generateKeyPair();
    final other = await signer.generateKeyPair();
    final body = await _signedBody(signer, key, [entry]);
    final mock = MockClient((req) async =>
        http.Response(jsonEncode(body), 200,
            headers: {'content-type': 'application/json'}));
    final client = CloudPackageClient.cloud(
      baseUrl: 'https://cloud.example',
      trustedRootHex: _hex(other.publicKey),
      client: mock,
    );
    final res = await client.fetchManifest();
    expect(res.ok, isFalse);
    expect(res.status, ManifestVerify.untrustedKey);
  });

  test('fetchManifest with no trusted root never claims verification',
      () async {
    final mock = MockClient((req) async => http.Response('{}', 200));
    final client = CloudPackageClient.cloud(
      baseUrl: 'https://cloud.example',
      trustedRootHex: '',
      client: mock,
    );
    final res = await client.fetchManifest();
    expect(res.ok, isFalse);
    expect(res.status, ManifestVerify.untrustedKey);
  });
}
