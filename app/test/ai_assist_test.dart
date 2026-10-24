import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resilience/ai/ai_assist.dart';
import 'package:resilience/ai/bedrock_ai_client.dart';
import 'package:resilience/ai/local_rules_ai.dart';

void main() {
  group('LocalRulesAiClient', () {
    const ai = LocalRulesAiClient();

    test('insulin example -> MEDICINE / high', () async {
      final r = await ai.structure(
          'my grandmother needs somewhere to keep her insulin cold');
      expect(r.category, 'MEDICINE');
      expect(r.priority, 'high');
      expect(r.degraded, isTrue);
      expect(r.shortTitle, isNotEmpty);
    });

    test('category mapping', () async {
      expect((await ai.structure('we have no drinking water')).category, 'WATER');
      expect((await ai.structure('someone is bleeding badly')).category,
          'MEDICAL_HELP');
      expect((await ai.structure('the shelter roof collapsed')).category,
          'SHELTER');
      expect((await ai.structure('asdf qwer')).category, 'OTHER');
    });

    test('translate offline returns original, not translated', () async {
      final t = await ai.translate('necesito agua', from: 'es', to: 'en');
      expect(t.translated, isFalse);
      expect(t.text, 'necesito agua');
      expect(t.degraded, isTrue);
    });

    test('summarize is deterministic, non-empty, and degraded', () async {
      final items = ['Water at center.', 'Road blocked.', 'Shelter open.'];
      final a = await ai.summarize(items);
      final b = await ai.summarize(items);
      expect(a.text, b.text);
      expect(a.text, isNotEmpty);
      // The rules fallback must always flag itself as degraded.
      expect(a.degraded, isTrue);
    });

    test('dedup flags a paraphrase, not an unrelated item', () async {
      final existing = [
        'Water available at community center on Main street',
        'Road obstruction near the highway bridge',
      ];
      final hits = await ai.dedup(
          'community center on Main street has water available', existing);
      expect(hits, isNotEmpty);
      expect(hits.first.index, 0);

      final none =
          await ai.dedup('need blankets for three people tonight', existing);
      expect(none, isEmpty);
    });
  });

  group('BedrockAiClient fallback', () {
    test('empty base URL -> uses local rules, degraded', () async {
      final c = BedrockAiClient(baseUrl: '', fallback: const LocalRulesAiClient());
      final r = await c.structure('insulin must stay cold');
      expect(r.category, 'MEDICINE');
      expect(r.degraded, isTrue);
    });

    test('unreachable URL -> falls back without throwing', () async {
      final c = BedrockAiClient(
        baseUrl: 'http://127.0.0.1:1', // closed port
        fallback: const LocalRulesAiClient(),
        timeout: const Duration(milliseconds: 300),
      );
      final r = await c.structure('we need water urgently');
      expect(r.category, 'WATER');
      expect(r.degraded, isTrue);
    });

    test('sends X-Api-Key and uses the live response', () async {
      String? seen;
      final c = BedrockAiClient(
        baseUrl: 'https://example.test',
        apiKey: 'k123',
        fallback: const LocalRulesAiClient(),
        httpClient: MockClient((http.Request req) async {
          seen = req.headers['X-Api-Key'] ?? req.headers['x-api-key'];
          return http.Response(
              '{"category":"SHELTER","priority":"high","short_title":"t","degraded":false}',
              200);
        }),
      );
      final r = await c.structure('gas leak');
      expect(seen, 'k123');
      expect(r.category, 'SHELTER');
      expect(r.degraded, isFalse);
    });
  });

  // UI-facing paths exercised through the AiAssist contract, as the Translate
  // panel, Home summary, and dedup warning consume them. We use the real
  // Bedrock client with a MockClient (live path) and a closed-port client
  // (offline fallback), so both the degraded flag and the offline fallback are
  // covered exactly as the UI sees them.
  group('Translate (UI path)', () {
    test('live cloud translation -> translated, not degraded', () async {
      final c = BedrockAiClient(
        baseUrl: 'https://example.test',
        fallback: const LocalRulesAiClient(),
        httpClient: MockClient((req) async => http.Response(
            '{"text":"I need water","from":"es","to":"en","translated":true,"degraded":false}',
            200)),
      );
      final t = await c.translate('necesito agua', from: 'auto', to: 'en');
      expect(t.text, 'I need water');
      expect(t.translated, isTrue);
      expect(t.degraded, isFalse);
    });

    test('cloud returns a degraded (rules) translation honestly', () async {
      final c = BedrockAiClient(
        baseUrl: 'https://example.test',
        fallback: const LocalRulesAiClient(),
        httpClient: MockClient((req) async => http.Response(
            '{"text":"necesito agua","from":"es","to":"en","translated":false,"degraded":true}',
            200)),
      );
      final t = await c.translate('necesito agua', from: 'auto', to: 'en');
      // Honesty: original text preserved, flagged degraded + not translated.
      expect(t.text, 'necesito agua');
      expect(t.translated, isFalse);
      expect(t.degraded, isTrue);
    });

    test('API down -> falls back to rules (original text, degraded)', () async {
      final c = BedrockAiClient(
        baseUrl: 'http://127.0.0.1:1',
        fallback: const LocalRulesAiClient(),
        timeout: const Duration(milliseconds: 300),
      );
      final t = await c.translate('necesito agua', from: 'auto', to: 'en');
      expect(t.text, 'necesito agua');
      expect(t.translated, isFalse);
      expect(t.degraded, isTrue);
    });
  });

  group('Summarize (UI path)', () {
    final items = ['Water at the center', 'Bridge is out', 'Shelter is open'];

    test('live cloud summary -> not degraded', () async {
      final c = BedrockAiClient(
        baseUrl: 'https://example.test',
        fallback: const LocalRulesAiClient(),
        httpClient: MockClient((req) async => http.Response(
            '{"summary":"Water, shelter available; bridge out.","degraded":false}',
            200)),
      );
      final s = await c.summarize(items);
      expect(s.text, contains('Water'));
      expect(s.degraded, isFalse);
    });

    test('API down -> rules summary, degraded', () async {
      final c = BedrockAiClient(
        baseUrl: 'http://127.0.0.1:1',
        fallback: const LocalRulesAiClient(),
        timeout: const Duration(milliseconds: 300),
      );
      final s = await c.summarize(items);
      expect(s.text, isNotEmpty);
      expect(s.degraded, isTrue);
    });
  });

  group('Dedup (UI path)', () {
    final existing = [
      'Water available at community center on Main street',
      'Road obstruction near the highway bridge',
    ];

    test('live cloud hit -> returns the near-duplicate', () async {
      final c = BedrockAiClient(
        baseUrl: 'https://example.test',
        fallback: const LocalRulesAiClient(),
        httpClient: MockClient((req) async => http.Response(
            '{"hits":[{"index":0,"text":"Water available at community center on Main street","score":0.8}],"degraded":false}',
            200)),
      );
      final hits = await c.dedup('water at the main street center', existing);
      expect(hits, isNotEmpty);
      expect(hits.first.index, 0);
      expect(hits.first.text, contains('community center'));
    });

    test('API down -> rules dedup still flags the paraphrase', () async {
      final c = BedrockAiClient(
        baseUrl: 'http://127.0.0.1:1',
        fallback: const LocalRulesAiClient(),
        timeout: const Duration(milliseconds: 300),
      );
      final hits = await c.dedup(
          'community center on Main street has water available', existing);
      expect(hits, isNotEmpty);
      expect(hits.first.index, 0);

      final none = await c.dedup('need blankets tonight', existing);
      expect(none, isEmpty);
    });
  });

  // A fake AiAssist like the UI widgets would inject, proving the contract is
  // consumable with a controllable degraded flag and offline behavior.
  group('Fake AiAssist contract', () {
    test('degraded flag and offline translate flow', () async {
      final fake = _FakeAiAssist(degraded: true, translated: false);
      final t = await fake.translate('hola', from: 'auto', to: 'en');
      expect(t.degraded, isTrue);
      expect(t.translated, isFalse);
      expect(t.text, 'hola');

      final s = await fake.summarize(['a', 'b']);
      expect(s.degraded, isTrue);

      final hits = await fake.dedup('x', ['x']);
      expect(hits, isNotEmpty);
    });

    test('live (non-degraded) fake path', () async {
      final fake = _FakeAiAssist(degraded: false, translated: true);
      final t = await fake.translate('hola', from: 'auto', to: 'en');
      expect(t.degraded, isFalse);
      expect(t.translated, isTrue);
      final s = await fake.summarize(['a']);
      expect(s.degraded, isFalse);
    });
  });
}

/// A controllable AiAssist double matching what the UI injects, used to assert
/// the degraded/offline-fallback UI behavior without a network.
class _FakeAiAssist implements AiAssist {
  _FakeAiAssist({required this.degraded, required this.translated});
  final bool degraded;
  final bool translated;

  @override
  Future<StructuredReport> structure(String text, {String langHint = ''}) async =>
      StructuredReport(
          category: 'OTHER',
          priority: 'low',
          shortTitle: text,
          normalizedNote: text,
          degraded: degraded);

  @override
  Future<TranslationResult> translate(String text,
          {required String from, required String to}) async =>
      TranslationResult(
          text: translated ? 'TRANSLATED: $text' : text,
          from: from,
          to: to,
          translated: translated,
          degraded: degraded);

  @override
  Future<SummaryResult> summarize(List<String> items) async =>
      SummaryResult(text: items.join(' '), degraded: degraded);

  @override
  Future<List<DupHit>> dedup(String candidate, List<String> existing) async =>
      existing.isEmpty
          ? const []
          : [DupHit(index: 0, text: existing.first, score: 0.9)];
}
