import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../../data/map_tiles.dart';
import '../../data/offline_map.dart';
import '../../l10n/labels.dart';
import '../../ui/surfaces.dart';

/// Gives a screen with a map its online street map, opened in the app's
/// light or dark look and in its language, and loads the offline one.
mixin StreetMapHost<T extends StatefulWidget> on State<T> {
  final tiles = MapTiles();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    tiles.open(
      dark: Theme.of(context).brightness == Brightness.dark,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    offlineMap.load();
  }

  @override
  void dispose() {
    tiles.dispose();
    super.dispose();
  }
}

/// Which street map shows right now, for this screen's look and language.
(StreetMap, Style?) currentStreetMap(BuildContext context, MapTiles tiles) => pickStreetMap(
      tiles,
      offlineMap,
      dark: Theme.of(context).brightness == Brightness.dark,
      languageCode: Localizations.localeOf(context).languageCode,
    );

/// Rebuilds when either street map changes.
class StreetMapBuilder extends StatelessWidget {
  const StreetMapBuilder({super.key, required this.tiles, required this.builder});

  final MapTiles tiles;
  final Widget Function(BuildContext context, StreetMap kind, Style? style) builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([tiles, offlineMap]),
      builder: (context, _) {
        final (kind, style) = currentStreetMap(context, tiles);
        return builder(context, kind, style);
      },
    );
  }
}

/// The streets under the pins: Amazon's map while it works, otherwise the
/// offline map, otherwise nothing (the pins still show on the background).
class StreetMapLayer extends StatelessWidget {
  const StreetMapLayer({super.key, required this.tiles});

  final MapTiles tiles;

  @override
  Widget build(BuildContext context) {
    return StreetMapBuilder(
      tiles: tiles,
      builder: (context, kind, style) => style == null
          ? const SizedBox.shrink()
          : VectorTileLayer(
              // A new key per style, so a theme, language or source change
              // redraws the map instead of reusing old tiles.
              key: ObjectKey(style),
              theme: style.theme,
              sprites: style.sprites,
              tileProviders: style.providers,
            ),
    );
  }
}

/// The data credit the map's terms ask for, for whichever map shows.
class StreetMapCredit extends StatelessWidget {
  const StreetMapCredit({super.key, required this.tiles});

  final MapTiles tiles;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreetMapBuilder(
      tiles: tiles,
      builder: (context, kind, _) => switch (kind) {
        StreetMap.online when tiles.attribution != null => MapChip(text: tiles.attribution!),
        StreetMap.offline => MapChip(text: offlineMap.attribution ?? l.mapOsmCredit),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

/// Why the online street map doesn't show, if it doesn't. When there is no
/// offline map either, a tap opens Offline downloads to get one.
class StreetMapStatus extends StatelessWidget {
  const StreetMapStatus({super.key, required this.tiles});

  final MapTiles tiles;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    void getOffline() => context.push('/more/downloads');
    return StreetMapBuilder(
      tiles: tiles,
      builder: (context, kind, _) => switch ((kind, tiles.status)) {
        (StreetMap.online, _) => const SizedBox.shrink(),
        (StreetMap.offline, _) => MapChip(icon: Icons.download_done, text: l.mapOfflineTitle),
        (_, MapTilesStatus.loading) => MapChip(icon: Icons.map_outlined, text: l.mapLoading),
        (_, MapTilesStatus.notSetUp) =>
          MapChip(icon: Icons.map_outlined, text: l.mapNotSetUp, onTap: getOffline, hint: l.mapOpenDownloads),
        _ => MapChip(icon: Icons.cloud_off, text: l.mapOffline, onTap: getOffline, hint: l.mapOpenDownloads),
      },
    );
  }
}

/// A small flat label that floats over the map. Its text wraps instead of
/// being cut off, at any text size. With [onTap] it is a 48 px button.
class MapChip extends StatelessWidget {
  const MapChip({
    super.key,
    required this.text,
    this.icon,
    this.onTap,
    this.hint,
    this.emphasis = false,
  });

  final String text;
  final IconData? icon;
  final VoidCallback? onTap;

  /// What a tap does, for screen readers.
  final String? hint;

  /// In the brand color, for the one thing the person should do next.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final color = emphasis ? c.primary : c.onSurfaceVariant;
    return Semantics(
      onTapHint: hint,
      child: Glass(
        radius: 16,
        shadow: onTap != null,
        onTap: onTap,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: onTap == null ? 4 : 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: onTap == null ? 0 : 32),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    color: emphasis ? c.primary : c.onSurfaceVariant,
                    fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 20, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A file size in megabytes, in the language's number format.
String megabytes(AppLocalizations l, int bytes) =>
    l.mapOfflineMegabytes(NumberFormat('0.0', l.localeName).format(bytes / (1024 * 1024)));
