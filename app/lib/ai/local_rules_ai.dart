import 'ai_assist.dart';

/// Deterministic, network-free AI fallback. Mirrors the Go RulesAssistant
/// (cloud/internal/ai/rules.go) so the offline path and the cloud-degraded
/// path agree. Always available; every result is marked degraded=true.
class LocalRulesAiClient implements AiAssist {
  const LocalRulesAiClient();

  static const double _dedupThreshold = 0.5;

  @override
  Future<StructuredReport> structure(String text, {String langHint = ''}) async {
    final norm = text.trim().toLowerCase();
    var category = 'OTHER';
    var high = false;
    for (final rule in _categoryRules) {
      if (_containsAny(norm, rule.subs)) {
        category = rule.category;
        high = rule.high;
        break;
      }
    }
    var priority = 'medium';
    if (high) priority = 'high';
    if (_containsAny(norm, _urgent)) priority = 'high';
    if (category == 'OTHER' && !_containsAny(norm, _urgent)) priority = 'low';

    return StructuredReport(
      category: category,
      priority: priority,
      shortTitle: _shortTitle(text, category),
      normalizedNote: _normalizeWs(text),
      degraded: true,
    );
  }

  @override
  Future<TranslationResult> translate(String text,
      {required String from, required String to}) async {
    // No offline translation model: return original, translated=false.
    return TranslationResult(
        text: text, from: from, to: to, translated: false, degraded: true);
  }

  @override
  Future<SummaryResult> summarize(List<String> items) async {
    return SummaryResult(text: summarizeText(items), degraded: true);
  }

  /// The deterministic summary string (shared so callers can compare against a
  /// cloud response without re-implementing the heuristic).
  static String summarizeText(List<String> items) {
    final cleaned =
        items.map(_normalizeWs).where((s) => s.isNotEmpty).toList();
    if (cleaned.isEmpty) return 'No reports to summarize.';
    final keep = <String>[];
    for (var i = cleaned.length - 1; i >= 0 && keep.length < 3; i--) {
      keep.add(cleaned[i]);
    }
    var summary = keep.join(' ');
    if (!summary.endsWith('.') &&
        !summary.endsWith('!') &&
        !summary.endsWith('?')) {
      summary += '.';
    }
    return summary;
  }

  @override
  Future<List<DupHit>> dedup(String candidate, List<String> existing) async {
    final c = _tokenize(candidate);
    final hits = <DupHit>[];
    for (var i = 0; i < existing.length; i++) {
      final score = _jaccard(c, _tokenize(existing[i]));
      if (score >= _dedupThreshold) {
        hits.add(DupHit(index: i, text: existing[i], score: score));
      }
    }
    hits.sort((a, b) {
      if (a.score != b.score) return b.score.compareTo(a.score);
      return a.index.compareTo(b.index);
    });
    return hits;
  }

  // --- heuristics (kept in sync with cloud/internal/ai/rules.go) ---

  static bool _containsAny(String s, List<String> subs) =>
      subs.any(s.contains);

  static String _shortTitle(String text, String category) {
    final norm = _normalizeWs(text);
    final words = norm.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return _titleCase(category);
    if (words.length > 6) return '${words.take(6).join(' ')}...';
    return words.join(' ');
  }

  static String _titleCase(String category) => category
      .toLowerCase()
      .split('_')
      .where((p) => p.isNotEmpty)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');

  static String _normalizeWs(String s) =>
      s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');

  static Set<String> _tokenize(String s) {
    return s
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.isNotEmpty && !_stopwords.contains(t))
        .toSet();
  }

  static double _jaccard(Set<String> a, Set<String> b) {
    if (a.isEmpty && b.isEmpty) return 0;
    final inter = a.where(b.contains).length;
    final union = a.length + b.length - inter;
    if (union == 0) return 0;
    return inter / union;
  }
}

class _Rule {
  final List<String> subs;
  final String category;
  final bool high;
  const _Rule(this.subs, this.category, this.high);
}

const _categoryRules = <_Rule>[
  _Rule([
    'insulin', 'refrigerat', 'medication', 'medicine', 'prescription',
    'pharmacy', 'antibiotic', 'epipen', 'inhaler'
  ], 'MEDICINE', true),
  _Rule([
    'injured', 'injury', 'bleeding', 'unconscious', 'doctor', 'nurse',
    'medic', 'ambulance', 'cpr', 'wound', 'medical help', 'medical'
  ], 'MEDICAL_HELP', true),
  _Rule(['water', 'thirsty', 'dehydrat', 'drinking'], 'WATER', true),
  _Rule(['food', 'hungry', 'meal', 'eat', 'starving', 'formula'], 'FOOD', false),
  _Rule(['shelter', 'homeless', 'roof', 'sleep', 'tent', 'housing', 'evacuat'],
      'SHELTER', true),
  _Rule(['power', 'generator', 'electricity', 'outage', 'blackout'], 'POWER',
      false),
  _Rule(['charge', 'charging', 'charger'], 'CHARGING', false),
  _Rule(['batter'], 'BATTERIES', false),
  _Rule(['blanket', 'cold', 'freezing', 'warm'], 'BLANKETS', false),
  _Rule(['ride', 'transport', 'truck', 'car', 'drive', 'vehicle', 'move'],
      'TRANSPORTATION', false),
  _Rule(['radio', 'signal', 'phone', 'comms', 'communication', 'internet'],
      'COMMUNICATION', false),
  _Rule(['tool', 'chainsaw', 'shovel'], 'TOOLS', false),
];

const _urgent = <String>[
  'urgent', 'emergency', 'immediately', 'asap', 'dying', 'critical', 'life',
  'now', 'trapped', 'baby', 'child', 'elderly', 'grandmother', 'grandfather'
];

const _stopwords = <String>{
  'a', 'an', 'the', 'and', 'or', 'to', 'of', 'in', 'on', 'at', 'for', 'is',
  'are', 'my', 'i', 'we', 'need', 'needs', 'with', 'some'
};
