import 'package:flutter/material.dart';

/// One seed color drives the whole theme, light and dark.
const seedColor = Color(0xFF2E7D6B);

/// Smallest text anywhere in the app. Below 16 px, iOS zooms into text
/// fields on focus, and small text is hard to read in an emergency.
const minFontSize = 16.0;

ThemeData buildTheme(Brightness brightness, {bool highContrast = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
    contrastLevel: highContrast ? 1.0 : 0.0,
  );
  final base = ThemeData(colorScheme: scheme);
  final text = _atLeast(base.textTheme);
  final label = text.labelLarge!.copyWith(fontWeight: FontWeight.w600);
  const buttonSize = Size(64, 52);

  return base.copyWith(
    textTheme: text,
    primaryTextTheme: _atLeast(base.primaryTextTheme),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: buttonSize, textStyle: label),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: buttonSize, textStyle: label),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48), textStyle: label),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: text.bodyLarge!.copyWith(color: scheme.onInverseSurface),
      actionTextColor: scheme.inversePrimary,
    ),
    bannerTheme: MaterialBannerThemeData(
      contentTextStyle: text.bodyLarge,
      backgroundColor: scheme.secondaryContainer,
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: text.bodyLarge!.copyWith(color: scheme.onInverseSurface),
    ),
    navigationRailTheme: NavigationRailThemeData(
      selectedLabelTextStyle: label.copyWith(color: scheme.onSurface),
      unselectedLabelTextStyle: text.labelLarge!.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: highContrast ? scheme.outline : scheme.outlineVariant,
          width: highContrast ? 2 : 1,
        ),
      ),
    ),
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

/// Space to leave under a tab's content, because the Help button sits half
/// over the bottom bar's edge.
const helpButtonClearance = 44.0;
