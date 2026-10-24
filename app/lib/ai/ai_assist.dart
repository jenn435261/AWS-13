// AI assist contract for the Flutter client.
//
// The emergency system works WITHOUT AI (spec §67): every capability has a
// deterministic offline fallback (LocalRulesAiClient). The online client
// (BedrockAiClient) calls the Go cloud's /v1/ai/* endpoints, which invoke
// Amazon Bedrock, and transparently falls back to local rules when offline or
// on any error. Results carry a `degraded` flag so the UI can say "offline
// suggestion".

class StructuredReport {
  final String category; // canonical ResourceCategory name (no prefix)
  final String priority; // "high" | "medium" | "low"
  final String shortTitle;
  final String normalizedNote;
  final bool degraded;
  const StructuredReport({
    required this.category,
    required this.priority,
    required this.shortTitle,
    required this.normalizedNote,
    required this.degraded,
  });
}

class TranslationResult {
  final String text;
  final String from;
  final String to;
  final bool translated;
  final bool degraded;
  const TranslationResult({
    required this.text,
    required this.from,
    required this.to,
    required this.translated,
    required this.degraded,
  });
}

class DupHit {
  final int index;
  final String text;
  final double score;
  const DupHit({required this.index, required this.text, required this.score});
}

abstract class AiAssist {
  Future<StructuredReport> structure(String text, {String langHint});
  Future<TranslationResult> translate(String text,
      {required String from, required String to});
  Future<String> summarize(List<String> items);
  Future<List<DupHit>> dedup(String candidate, List<String> existing);
}
