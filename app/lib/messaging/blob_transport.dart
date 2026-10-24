import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Uploads and downloads opaque, content-addressed encrypted attachment blobs
/// to the cloud (`/v1/blobs/{sha256}`, client-key gated) and/or an active node
/// (`/node/v1/blobs/{sha256}`).
///
/// Everything handed to [put] is already ciphertext; the decryption key rides
/// inside the E2E message and never passes through here. The content address
/// [sha256] is the SHA-256 of the ciphertext.
abstract class BlobTransport {
  /// Store [ciphertext] under [sha256]. Returns true when at least one endpoint
  /// accepted it.
  Future<bool> put(String sha256, Uint8List ciphertext);

  /// Fetch the ciphertext stored under [sha256], or null when no configured
  /// endpoint has it.
  Future<Uint8List?> get(String sha256);
}

/// A configured blob endpoint (base URL + optional API key).
class BlobEndpoint {
  BlobEndpoint({required this.baseUrl, required this.path, this.apiKey = ''});

  /// e.g. https://api.example.com (no trailing slash).
  final String baseUrl;

  /// e.g. /v1/blobs/ (cloud) or /node/v1/blobs/ (node).
  final String path;

  /// X-Api-Key value; empty => no header.
  final String apiKey;

  Uri uriFor(String sha256) => Uri.parse('$baseUrl$path$sha256');
  Map<String, String> get headers =>
      apiKey.isEmpty ? const <String, String>{} : {'X-Api-Key': apiKey};
}

/// Default [BlobTransport] over the `http` package. Writes to every configured
/// endpoint (best-effort) and reads from the first that has the blob.
class HttpBlobTransport implements BlobTransport {
  HttpBlobTransport({
    required List<BlobEndpoint> endpoints,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  })  : _endpoints = endpoints,
        _client = client ?? http.Client();

  final List<BlobEndpoint> _endpoints;
  final http.Client _client;
  final Duration timeout;

  @override
  Future<bool> put(String sha256, Uint8List ciphertext) async {
    var anyOk = false;
    for (final e in _endpoints) {
      try {
        final r = await _client
            .put(e.uriFor(sha256),
                headers: {...e.headers, 'Content-Type': 'application/octet-stream'},
                body: ciphertext)
            .timeout(timeout);
        if (r.statusCode == 200 || r.statusCode == 201) anyOk = true;
      } catch (_) {
        // Try the next endpoint; a failed upload is surfaced by anyOk=false.
      }
    }
    return anyOk;
  }

  @override
  Future<Uint8List?> get(String sha256) async {
    for (final e in _endpoints) {
      try {
        final r =
            await _client.get(e.uriFor(sha256), headers: e.headers).timeout(timeout);
        if (r.statusCode == 200) return r.bodyBytes;
      } catch (_) {
        // Try the next endpoint.
      }
    }
    return null;
  }
}

/// In-memory blob transport for tests (a stand-in cloud/node that holds only
/// ciphertext, keyed by sha256).
class InMemoryBlobTransport implements BlobTransport {
  final Map<String, Uint8List> _store = <String, Uint8List>{};

  /// The raw bytes the "server" holds — tests assert these are only ciphertext.
  Map<String, Uint8List> get stored => _store;

  @override
  Future<bool> put(String sha256, Uint8List ciphertext) async {
    _store[sha256] = Uint8List.fromList(ciphertext);
    return true;
  }

  @override
  Future<Uint8List?> get(String sha256) async => _store[sha256];
}
