import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Smallest text anywhere in the app. Below 16 px, iOS zooms into text
/// fields on focus, and small text is hard to read in an emergency.
const minFontSize = 16.0;

/// The bundled font (see pubspec.yaml), so text looks the same offline.
const fontFamily = 'Jakarta';

/// Space the lock screen leaves under its content for the Help button.
const helpButtonClearance = 44.0;

/// Space to leave under a tab's scrolling content. The bottom bar floats over
/// the content, and the shell reports its height as bottom padding.
double bottomClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 16;

/// Colors the Material scheme has no slot for: the panels that float over
/// the map, their shadow, and the map overlays.
///
/// Everything is flat (rule 14): solid fills, a thin outline, and one small
/// grey shadow only under things that float. Nothing is blurred or glows.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.glass,
    required this.glassBorder,
    required this.shadow,
    required this.map,
    this.borderWidth = 1,
  });

  /// Fill of the panels over the map and of the bottom bar. Always solid,
  /// so text on it keeps its contrast over any street.
  final Color glass;

  /// The thin outline around those panels; darker in high contrast.
  final Color glassBorder;

  /// 1 normally, 2 in high contrast.
  final double borderWidth;

  /// The one plain grey shadow, for things that float.
  final Color shadow;
  final MapColors map;

  /// Nothing in the app is blurred (rule 14), so this is always 0. Kept so
  /// older code that read it still compiles.
  double get blur => 0;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) => t < 0.5 ? this : other ?? this;
}

/// Colors for what the app draws on the map.
@immutable
class MapColors {
  const MapColors({required this.base, required this.mesh});

  /// Behind the street map, and all that shows when it can't load.
  final Color base;

  /// Radio links and coverage.
  final Color mesh;
}

ColorScheme _scheme(Brightness brightness, bool highContrast) {
  final dark = brightness == Brightness.dark;
  if (dark) {
    return ColorScheme(
      brightness: brightness,
      primary: const Color(0xFF3DDBB9),
      onPrimary: const Color(0xFF00382F),
      primaryContainer: const Color(0xFF0E4A40),
      onPrimaryContainer: const Color(0xFFB4F5E6),
      secondary: const Color(0xFFA9B8D9),
      onSecondary: const Color(0xFF132037),
      secondaryContainer: const Color(0xFF243150),
      onSecondaryContainer: const Color(0xFFDCE4F7),
      tertiary: const Color(0xFFA5A1FF),
      onTertiary: const Color(0xFF1B1863),
      tertiaryContainer: const Color(0xFF2F2C7A),
      onTertiaryContainer: const Color(0xFFE2E0FF),
      error: const Color(0xFFFF8A80),
      onError: const Color(0xFF5C0A12),
      errorContainer: const Color(0xFF5A1622),
      onErrorContainer: const Color(0xFFFFDAD8),
      surface: highContrast ? Colors.black : const Color(0xFF0B1220),
      onSurface: highContrast ? Colors.white : const Color(0xFFE8ECF5),
      onSurfaceVariant: highContrast ? const Color(0xFFDCE2EE) : const Color(0xFFA3AEC4),
      surfaceContainerLowest: const Color(0xFF070C17),
      surfaceContainerLow: const Color(0xFF111A2C),
      surfaceContainer: const Color(0xFF151F33),
      surfaceContainerHigh: const Color(0xFF1B263D),
      surfaceContainerHighest: const Color(0xFF223049),
      outline: highContrast ? const Color(0xFFC7CEDB) : const Color(0xFF8792A8),
      outlineVariant: highContrast ? const Color(0xFF8792A8) : const Color(0xFF26324B),
      inverseSurface: const Color(0xFFE8ECF5),
      onInverseSurface: const Color(0xFF121826),
      inversePrimary: const Color(0xFF0A7363),
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );
  }
  return ColorScheme(
    brightness: brightness,
    primary: const Color(0xFF0A7363),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFCFF1E9),
    onPrimaryContainer: const Color(0xFF00382F),
    secondary: const Color(0xFF3A4766),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFE3E8F4),
    onSecondaryContainer: const Color(0xFF121A2E),
    tertiary: const Color(0xFF4C4BD6),
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFE5E4FF),
    onTertiaryContainer: const Color(0xFF16145C),
    error: const Color(0xFFC81E3C),
    onError: Colors.white,
    errorContainer: const Color(0xFFFFE1E2),
    onErrorContainer: const Color(0xFF5C0A12),
    surface: highContrast ? Colors.white : const Color(0xFFF5F7FB),
    onSurface: highContrast ? Colors.black : const Color(0xFF121826),
    onSurfaceVariant: highContrast ? const Color(0xFF2B3240) : const Color(0xFF4A5468),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFEFF2F8),
    surfaceContainer: const Color(0xFFE9EDF4),
    surfaceContainerHigh: const Color(0xFFE4E8F0),
    surfaceContainerHighest: const Color(0xFFDDE2EB),
    outline: highContrast ? const Color(0xFF3B4352) : const Color(0xFF5E687C),
    outlineVariant: highContrast ? const Color(0xFF5E687C) : const Color(0xFFD7DCE5),
    inverseSurface: const Color(0xFF1B2232),
    onInverseSurface: const Color(0xFFEEF1F7),
    inversePrimary: const Color(0xFF3DDBB9),
    shadow: const Color(0xFF0B1220),
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );
}

AppColors _appColors(ColorScheme c, bool highContrast) {
  final dark = c.brightness == Brightness.dark;
  return AppColors(
    // Solid, a step lighter than the page in dark mode so panels stand out.
    glass: highContrast
        ? c.surface
        : dark
            ? c.surfaceContainerLow
            : c.surfaceContainerLowest,
    glassBorder: highContrast ? c.outline : c.outlineVariant,
    borderWidth: highContrast ? 2 : 1,
    // Black at low strength reads as plain grey on any color.
    shadow: dark ? const Color(0x66000000) : const Color(0x1F000000),
    map: dark
        ? const MapColors(base: Color(0xFF111A2C), mesh: Color(0xFF3DDBB9))
        : const MapColors(base: Color(0xFFE9EDF4), mesh: Color(0xFF0A7363)),
  );
}

ThemeData buildTheme(Brightness brightness, {bool highContrast = false}) {
  final scheme = _scheme(brightness, highContrast);
  final extra = _appColors(scheme, highContrast);
  final base = ThemeData(
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: scheme.surface,
  );
  // ThemeData keeps sizes apart from colors until Theme.of; merge them here
  // so the 16 px floor raises only the small styles, not the headings.
  final text = _styled(
    _atLeast(base.typography.englishLike.merge(base.textTheme)),
    scheme,
  );
  final label = text.labelLarge!.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.1);
  const buttonSize = Size(64, 56);
  const pill = StadiumBorder();
  final border = BorderSide(
    color: highContrast ? scheme.outline : scheme.outlineVariant,
    width: highContrast ? 2 : 1,
  );

  return base.copyWith(
    textTheme: text,
    primaryTextTheme: _atLeast(base.typography.englishLike.merge(base.primaryTextTheme)),
    extensions: [extra],
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge!.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: scheme.onSurface,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        textStyle: label,
        shape: pill,
        padding: const EdgeInsets.symmetric(horizontal: 24),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        textStyle: label,
        shape: pill,
        side: border.copyWith(color: highContrast ? scheme.outline : scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 24),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: label,
        shape: pill,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      foregroundColor: scheme.primary,
      elevation: 2,
      shape: const CircleBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyLarge!.copyWith(
        color: scheme.onInverseSurface,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: scheme.inversePrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
    ),
    bannerTheme: MaterialBannerThemeData(
      contentTextStyle: text.bodyLarge,
      backgroundColor: scheme.secondaryContainer,
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: text.bodyLarge!.copyWith(color: scheme.onInverseSurface),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
      selectedLabelTextStyle: label.copyWith(color: scheme.onSurface),
      unselectedLabelTextStyle: text.labelLarge!.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: border,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: border,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLowest,
      shadowColor: extra.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: border,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: text.titleMedium!.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      subtitleTextStyle: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: scheme.outline,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: border,
      labelStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w600),
      backgroundColor: scheme.surfaceContainerLowest,
      selectedColor: scheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: label,
      unselectedLabelStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w600),
      labelColor: scheme.onPrimaryContainer,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      indicator: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      splashBorderRadius: BorderRadius.circular(999),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(48, 52),
        textStyle: label,
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? scheme.onPrimary : scheme.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.surfaceContainerHighest,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.transparent : scheme.outline,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
  );
}

/// Weights and spacing for the bundled font: heavy, tight headings and calm
/// body text.
TextTheme _styled(TextTheme t, ColorScheme c) {
  TextStyle? heading(TextStyle? s, double spacing) =>
      s?.copyWith(fontWeight: FontWeight.w800, letterSpacing: spacing, height: 1.15);
  return t.copyWith(
    displayLarge: heading(t.displayLarge, -1.2),
    displayMedium: heading(t.displayMedium, -1),
    displaySmall: heading(t.displaySmall, -0.8),
    headlineLarge: heading(t.headlineLarge, -0.8),
    headlineMedium: heading(t.headlineMedium, -0.6),
    headlineSmall: heading(t.headlineSmall, -0.4),
    titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.1),
    titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    bodyLarge: t.bodyLarge?.copyWith(fontWeight: FontWeight.w500, height: 1.4),
    bodyMedium: t.bodyMedium?.copyWith(fontWeight: FontWeight.w500, height: 1.4),
    labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );
}

/// Raises every style below [minFontSize] to it, keeping weights and colors.
TextTheme _atLeast(TextTheme t) {
  TextStyle? raise(TextStyle? s) =>
      s == null || (s.fontSize ?? 0) >= minFontSize
          ? s
          : s.copyWith(fontSize: minFontSize, height: 1.35);

  return t.copyWith(
    displayLarge: raise(t.displayLarge),
    displayMedium: raise(t.displayMedium),
    displaySmall: raise(t.displaySmall),
    headlineLarge: raise(t.headlineLarge),
    headlineMedium: raise(t.headlineMedium),
    headlineSmall: raise(t.headlineSmall),
    titleLarge: raise(t.titleLarge),
    titleMedium: raise(t.titleMedium),
    titleSmall: raise(t.titleSmall),
    bodyLarge: raise(t.bodyLarge),
    bodyMedium: raise(t.bodyMedium),
    bodySmall: raise(t.bodySmall),
    labelLarge: raise(t.labelLarge),
    labelMedium: raise(t.labelMedium),
    labelSmall: raise(t.labelSmall),
  );
}
