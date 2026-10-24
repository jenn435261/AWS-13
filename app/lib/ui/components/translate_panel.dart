import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_assist.dart';
import '../../app/providers.dart';
import '../../l10n/strings.dart';

/// A small, reusable "Translate" affordance that sits under a piece of
/// user-generated text (a help request / offer note, or a chat message).
///
/// Honesty rules (spec §67, FEAT-006):
///  * The ORIGINAL text stays visible at all times — translation is additive.
///  * The result comes from the cloud Bedrock endpoint via [aiAssistProvider];
///    if the cloud is unreachable (or returns degraded/rules output), the
///    result carries `degraded == true` and we show an honest "offline
///    (rules-based)" chip, never implying a live AI translation.
///  * The local rules fallback has no translation model, so it returns the
///    original text with `translated == false`; we surface that truthfully.
class TranslatePanel extends ConsumerStatefulWidget {
  const TranslatePanel({
    super.key,
    required this.text,
    this.compact = false,
  });

  /// The source text to translate. Empty text renders nothing.
  final String text;

  /// Compact mode uses a dense inline button (for chat bubbles).
  final bool compact;

  @override
  ConsumerState<TranslatePanel> createState() => _TranslatePanelState();
}

class _TranslatePanelState extends ConsumerState<TranslatePanel> {
  TranslationResult? _result;
  bool _busy = false;
  bool _failed = false;

  String get _targetLang {
    final override = ref.read(localeProvider)?.languageCode;
    if (override != null && override.isNotEmpty) return override;
    final ctxLocale = Localizations.localeOf(context).languageCode;
    return ctxLocale.isEmpty ? 'en' : ctxLocale;
  }

  Future<void> _translate() async {
    if (widget.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ai = ref.read(aiAssistProvider);
    try {
      final r =
          await ai.translate(widget.text, from: 'auto', to: _targetLang);
      if (!mounted) return;
      setState(() => _result = r);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    if (widget.text.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    if (_result == null) {
      // Not translated yet: a single Translate button (or spinner).
      final button = OutlinedButton.icon(
        onPressed: _busy ? null : _translate,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.translate_rounded, size: 18),
        label: Text(_busy ? l.t('translating') : l.t('translate'),
            style: const TextStyle(fontSize: 16)),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
              alignment:
                  widget.compact ? Alignment.centerLeft : Alignment.centerLeft,
              child: button),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l.t('translate_failed'),
                  style: TextStyle(fontSize: 16, color: scheme.error)),
            ),
        ],
      );
    }

    final r = _result!;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.translate_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text(l.t('ai_translation'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              // Honest indicator: degraded OR "not actually translated" both
              // mean this is NOT a live AI translation.
              if (r.degraded || !r.translated) _degradedChip(l, scheme),
            ],
          ),
          const SizedBox(height: 6),
          Text(r.text, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _result = null),
              child: Text(l.t('show_original'),
                  style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _degradedChip(L10n l, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(l.t('ai_degraded'),
          style: TextStyle(fontSize: 16, color: scheme.onTertiaryContainer)),
    );
  }
}
