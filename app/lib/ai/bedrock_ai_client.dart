import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_assist.dart';
import 'local_rules_ai.dart';

/// Online AI client: POSTs to the Go cloud's /v1/ai/* endpoints (which invoke
/// Amazon Bedrock). On ANY failure — empty base URL, timeout, non-2xx, parse
/// error — it transparently delegates to [fallback] (local rules) and the
/// result is marked degraded=true. This is what makes the app work offline by
/// construction: the AI never blocks or throws into the UI.
class BedrockAiClient implements AiAssist {
  final String baseUrl;

  /// Shared client key sent as X-Api-Key (the cloud's CLIENT_API_KEYS gate).
  /// Empty => no header (works against an ungated server).
  final String apiKey;
  final LocalRulesAiClient fallback;
  final http.Client _http;
  final Duration timeout;

  BedrockAiClient({
    required this.baseUrl,
    required this.fallback,
    this.apiKey = '',
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 6),
  }) : _http = httpClient ?? http.Client();

  Uri _u(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');

  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    if (baseUrl.isEmpty) return null;
    try {
      final resp = await _http
          .post(_u(path),
              headers: {
                'Content-Type': 'application/json',
                if (apiKey.isNotEmpty) 'X-Api-Key': apiKey,
              },
              body: jsonEncode(body))
          .timeout(timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null; // any failure => fall back
    }
  }

  @override
  Future<StructuredReport> structure(String text, {String langHint = ''}) async {
    final j = await _post('/v1/ai/structure', {
      'text': text,
      'lang_hint': langHint,
    });
    if (j == null) return fallback.structure(text, langHint: langHint);
    return StructuredReport(
      category: (j['category'] ?? 'OTHER').toString(),
      priority: (j['priority'] ?? 'medium').toString(),
      shortTitle: (j['short_title'] ?? '').toString(),
      normalizedNote: (j['normalized_note'] ?? text).toString(),
      degraded: j['degraded'] == true,
    );
  }

  @override
  Future<TranslationResult> translate(String text,
      {required String from, required String to}) async {
    final j = await _post('/v1/ai/translate', {
      'text': text,
      'from': from,
      'to': to,
    });
    if (j == null) return fallback.translate(text, from: from, to: to);
    return TranslationResult(
      text: (j['text'] ?? text).toString(),
      from: (j['from'] ?? from).toString(),
      to: (j['to'] ?? to).toString(),
      translated: j['translated'] == true,
      degraded: j['degraded'] == true,
    );
  }

  @override
  Future<SummaryResult> summarize(List<String> items) async {
    final j = await _post('/v1/ai/summarize', {'items': items});
    if (j == null) return fallback.summarize(items);
    return SummaryResult(
      text: (j['summary'] ?? '').toString(),
      degraded: j['degraded'] == true,
    );
  }

  @override
  Future<List<DupHit>> dedup(String candidate, List<String> existing) async {
    final j = await _post('/v1/ai/dedup', {
      'candidate': candidate,
      'existing': existing,
    });
    if (j == null) return fallback.dedup(candidate, existing);
    final hits = (j['hits'] as List?) ?? const [];
    return hits
        .whereType<Map>()
        .map((h) => DupHit(
              index: (h['index'] ?? 0) as int,
              text: (h['text'] ?? '').toString(),
              score: ((h['score'] ?? 0) as num).toDouble(),
            ))
        .toList();
  }
}
