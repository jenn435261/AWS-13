import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

    test('summarize is deterministic and non-empty', () async {
      final items = ['Water at center.', 'Road blocked.', 'Shelter open.'];
      final a = await ai.summarize(items);
      final b = await ai.summarize(items);
      expect(a, b);
      expect(a, isNotEmpty);
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
}
