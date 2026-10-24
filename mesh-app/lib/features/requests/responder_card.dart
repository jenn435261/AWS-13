import 'package:flutter/material.dart';

import '../../l10n/labels.dart';
import '../../models/help.dart';
import '../../state/app_scope.dart';
import '../../state/settings_controller.dart';
import '../../ui/feedback.dart';
import '../../ui/visuals.dart';

/// A full-screen, high-contrast card to hand to a responder or a help desk.
/// Swipe to show it in another language. Works offline: the choices are
/// translated ahead of time; only the person's own note stays as written.
class ResponderCard extends StatefulWidget {
  const ResponderCard({super.key, required this.id});

  final String id;

  @override
  State<ResponderCard> createState() => _ResponderCardState();
}

class _ResponderCardState extends State<ResponderCard> {
  static final _codes = supportedLanguages.keys.toList();
  PageController? _controller;
  int _index = 0;

  PageController get _pages => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    // Start on a language other than the person's own: the responder's.
    final mine = Localizations.localeOf(context).languageCode;
    _index = mine == 'en' ? 1 : 0;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _go(int index) {
    Haptics.tick();
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<HelpRequest>>(
      valueListenable: scope.repository.requests,
      builder: (context, requests, _) => _build(
        context,
        l,
        c,
        requests.where((r) => r.id == widget.id).firstOrNull,
      ),
    );
  }

  Widget _build(
    BuildContext context,
    AppLocalizations l,
    ColorScheme c,
    HelpRequest? request,
  ) {
    return Theme(
      // Always the high-contrast dark look, whatever the app theme.
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: c.primary,
          brightness: Brightness.dark,
          contrastLevel: 1,
        ),
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
      ),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(l.showToResponder),
          ),
          body: request == null
              ? Center(child: Text(l.requestNotFound))
              : Column(
                  children: [
                    SizedBox(
                      height: 56,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          for (final (i, code) in _codes.indexed)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text(supportedLanguages[code]!),
                                selected: i == _index,
                                onSelected: (_) => _go(i),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pages,
                        onPageChanged: (i) {
                          Haptics.tick();
                          setState(() => _index = i);
                        },
                        children: [
                          for (final code in _codes)
                            _CardPage(
                              request: request,
                              words: lookupAppLocalizations(Locale(code)),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.swipe, color: Colors.white70),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              l.cardSwipeHint,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CardPage extends StatelessWidget {
  const _CardPage({required this.request, required this.words});

  final HelpRequest request;

  /// The language this page is shown in.
  final AppLocalizations words;

  @override
  Widget build(BuildContext context) {
    final w = words;
    final r = request;
    final theme = Theme.of(context);
    const yellow = Color(0xFFFFD54F);

    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: yellow, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70)),
                    Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

    return Localizations.override(
      context: context,
      locale: Locale(w.localeName),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Text(
            w.cardNeedHelp,
            style: theme.textTheme.displaySmall?.copyWith(
              color: yellow,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            w.requestTitle(r),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 28),
          row(urgencyIcon(r.urgency), w.urgencyTitle,
              '${w.urgency(r.urgency)}. ${w.urgencySub(r.urgency)}'),
          row(Icons.groups, w.peopleTitle, w.peopleCount(r.people)),
          if (r.location != null)
            row(
              Icons.place,
              w.locationTitle,
              '${r.location!.latitude.toStringAsFixed(5)}, '
                  '${r.location!.longitude.toStringAsFixed(5)}',
            ),
          if (r.locationNote.isNotEmpty || r.note.isNotEmpty) ...[
            Text(
              w.cardTheirWords,
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            for (final note in [r.locationNote, r.note])
              if (note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    note,
                    style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
