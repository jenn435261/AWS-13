import 'package:flutter/material.dart';

/// The single source of truth for Resilience Network's visual theme.
///
/// Hard rules enforced here:
///  * NO text smaller than [kMinTextSize] (16) — iOS zoom bug. Every text
///    style in the theme is clamped to >= 16 (see [_minSize]). A unit test
///    asserts this invariant.
///  * Large tap targets (>= [kMinTapTarget] = 48) for accessibility.
///  * High-contrast, Material 3 color scheme that works in bright outdoor
///    emergency conditions.
///  * No emojis anywhere — icons + typography only.
class AppTheme {
  /// Minimum font size in logical pixels. Never render text below this.
  static const double kMinTextSize = 16;

  /// Minimum interactive target size (accessibility).
  static const double kMinTapTarget = 48;

  /// Primary brand color — a strong, high-contrast blue that reads in sunlight.
  static const Color _seed = Color(0xFF0B5FFF);

  /// Emergency/urgent accent (used sparingly, e.g. the I NEED HELP action).
  static const Color urgent = Color(0xFFD32F2F);
  static const Color verified = Color(0xFF1B7F3B);
  static const Color communityAccent = Color(0xFF6B4EFF);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      // Explicit family so text styles resolve to the same font. Explicitly
      // constructed TextStyles in widgets should also pass fontFamily where
      // they set size/weight, so headless rendering matches the device.
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      textTheme: _enforceMinSize(base.textTheme),
      // Large, legible, high-contrast components.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(kMinTapTarget, kMinTapTarget),
          textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 18, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(kMinTapTarget, kMinTapTarget),
          textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 17, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(kMinTapTarget, kMinTapTarget),
          textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSecondaryContainer,
        ),
        selectedColor: scheme.secondaryContainer,
        backgroundColor: scheme.surface,
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.all(const IconThemeData(size: 28)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        labelStyle: TextStyle(fontSize: 16),
        hintStyle: TextStyle(fontSize: 16),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        subtitleTextStyle: TextStyle(fontSize: 16),
      ),
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: const TextStyle(fontSize: 16),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Clamps every style in a [TextTheme] to at least [kMinTextSize].
  static TextTheme _enforceMinSize(TextTheme t) {
    TextStyle? f(TextStyle? s) =>
        s?.copyWith(fontSize: _minSize(s.fontSize));
    return t.copyWith(
      displayLarge: f(t.displayLarge),
      displayMedium: f(t.displayMedium),
      displaySmall: f(t.displaySmall),
      headlineLarge: f(t.headlineLarge),
      headlineMedium: f(t.headlineMedium),
      headlineSmall: f(t.headlineSmall),
      titleLarge: f(t.titleLarge),
      titleMedium: f(t.titleMedium),
      titleSmall: f(t.titleSmall),
      bodyLarge: f(t.bodyLarge),
      bodyMedium: f(t.bodyMedium),
      bodySmall: f(t.bodySmall),
      labelLarge: f(t.labelLarge),
      labelMedium: f(t.labelMedium),
      labelSmall: f(t.labelSmall),
    );
  }

  static double _minSize(double? size) {
    if (size == null) return kMinTextSize;
    return size < kMinTextSize ? kMinTextSize : size;
  }
}
