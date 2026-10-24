import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../nodes/package_manifest.dart';
import 'resumable_download.dart';

/// A [RangeHttp] backed by the `http` package. It sends a `Range` header so the
/// server replies 206 Partial Content; a server that ignores Range (200 full
/// body) is still handled by slicing locally, so a resumable download works
/// even against a non-Range origin (just less efficiently).
class HttpRangeHttp implements RangeHttp {
  HttpRangeHttp({
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
    this.apiKey = '',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;
  final String apiKey;

  @override
  Future<Uint8List> getRange(Uri url, int start, int end) async {
    final headers = <String, String>{'Range': 'bytes=$start-$end'};
    if (apiKey.isNotEmpty) headers['X-Api-Key'] = apiKey;
    final r = await _client.get(url, headers: headers).timeout(timeout);
    if (r.statusCode == 206) {
      return r.bodyBytes;
    }
    if (r.statusCode == 200) {
      // Server ignored Range: slice the full body to the requested window.
      final body = r.bodyBytes;
      final to = (end + 1).clamp(0, body.length);
      final from = start.clamp(0, body.length);
      return Uint8List.sublistView(body, from, to);
    }
    throw Exception('range HTTP ${r.statusCode}');
  }
}

/// Fetches and verifies a signed package manifest from a cloud or node base URL
/// and builds the download URL for each entry. Verification reuses the SAME
/// [verifySignedManifest] the offline screen uses, against the trusted root for
/// the source (the cloud feed/packages root, or the node's packages root).
class CloudPackageClient {
  /// Base URL with no trailing slash.
  final String baseUrl;

  /// The trusted Ed25519 root (lowercase hex) the manifest must be signed by.
  /// Empty => the manifest cannot be trusted; [fetchManifest] returns an
  /// untrusted result rather than claiming verification.
  final String trustedRootHex;

  final String apiKey;
  final http.Client _client;
  final Duration timeout;

  /// The manifest path differs by source: the cloud exposes
  /// /v1/packages/manifest, the node /node/v1/manifest.
  final String manifestPath;

  CloudPackageClient._with({
    required this.baseUrl,
    required this.trustedRootHex,
    required this.apiKey,
    required http.Client client,
    required this.timeout,
    required this.manifestPath,
  }) : _client = client;

  /// A client for the cloud API (`/v1/packages/manifest`, `/v1/packages/{id}`).
  factory CloudPackageClient.cloud({
    required String baseUrl,
    required String trustedRootHex,
    String apiKey = '',
    http.Client? client,
  }) =>
      CloudPackageClient._with(
        baseUrl: baseUrl.replaceAll(RegExp(r'/+$'), ''),
        trustedRootHex: trustedRootHex,
        apiKey: apiKey,
        client: client ?? http.Client(),
        timeout: const Duration(seconds: 15),
        manifestPath: '/v1/packages/manifest',
      );

  /// A client for a node (`/node/v1/manifest`, `/node/v1/{...}`).
  factory CloudPackageClient.node({
    required String baseUrl,
    required String trustedRootHex,
    http.Client? client,
  }) =>
      CloudPackageClient._with(
        baseUrl: baseUrl.replaceAll(RegExp(r'/+$'), ''),
        trustedRootHex: trustedRootHex,
        apiKey: '',
        client: client ?? http.Client(),
        timeout: const Duration(seconds: 15),
        manifestPath: '/node/v1/manifest',
      );

  /// Fetches the signed manifest and verifies it against [trustedRootHex].
  /// Returns an honest [SignedManifestResult]: `ok` only when the embedded key
  /// equals the trusted root and the detached signature verifies. A transport
  /// failure or missing root yields a non-ok result, never a fake verification.
  Future<SignedManifestResult> fetchManifest() async {
    if (trustedRootHex.trim().isEmpty) {
      return const SignedManifestResult(ManifestVerify.untrustedKey);
    }
    try {
      final headers = <String, String>{'Accept': 'application/json'};
      if (apiKey.isNotEmpty) headers['X-Api-Key'] = apiKey;
      final r = await _client
          .get(Uri.parse('$baseUrl$manifestPath'), headers: headers)
          .timeout(timeout);
      if (r.statusCode != 200) {
        return const SignedManifestResult(ManifestVerify.malformed);
      }
      final body = jsonDecode(utf8.decode(r.bodyBytes));
      if (body is! Map<String, dynamic>) {
        return const SignedManifestResult(ManifestVerify.malformed);
      }
      return await verifySignedManifest(body, trustedRootHex);
    } catch (_) {
      return const SignedManifestResult(ManifestVerify.malformed);
    }
  }

  /// The absolute download URL for a manifest entry (its `path` is server-
  /// relative).
  Uri urlForEntry(ManifestEntry entry) {
    if (entry.path.startsWith('http')) return Uri.parse(entry.path);
    return Uri.parse('$baseUrl${entry.path}');
  }

  /// A [RangeHttp] for resumable downloads from this source.
  RangeHttp rangeHttp() => HttpRangeHttp(client: _client, apiKey: apiKey);
}
