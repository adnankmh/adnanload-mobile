import 'package:flutter/material.dart';

/// Three deliberate production palettes. Gold is a LIGHT palette.
class BrandThemes {
  static const names = ['dark', 'light', 'gold'];

  /// TextTheme.apply(fontSizeFactor: ...) asserts if a style has no fontSize.
  /// Flutter's default Material themes may contain such inherited styles.
  /// Give each Material 3 slot a safe concrete base before scaling.
  static TextTheme _scaledTextTheme(TextTheme base, double factor) {
    TextStyle? scaled(TextStyle? style, double fallback) => style?.copyWith(
      fontSize: (style.fontSize ?? fallback) * factor,
    );
    return base.copyWith(
      displayLarge: scaled(base.displayLarge, 57),
      displayMedium: scaled(base.displayMedium, 45),
      displaySmall: scaled(base.displaySmall, 36),
      headlineLarge: scaled(base.headlineLarge, 32),
      headlineMedium: scaled(base.headlineMedium, 28),
      headlineSmall: scaled(base.headlineSmall, 24),
      titleLarge: scaled(base.titleLarge, 22),
      titleMedium: scaled(base.titleMedium, 16),
      titleSmall: scaled(base.titleSmall, 14),
      bodyLarge: scaled(base.bodyLarge, 16),
      bodyMedium: scaled(base.bodyMedium, 14),
      bodySmall: scaled(base.bodySmall, 12),
      labelLarge: scaled(base.labelLarge, 14),
      labelMedium: scaled(base.labelMedium, 12),
      labelSmall: scaled(base.labelSmall, 11),
    );
  }

  /// Keep typography usable even when a restored preference is malformed.
  /// Match the supported accessibility zoom range in Settings, while treating
  /// NaN, infinity and nonpositive values as the default (not maximum zoom).
  static double _safeFontScale(double scale) {
    if (!scale.isFinite || scale <= 0) return 1.0;
    return scale.clamp(0.9, 1.35).toDouble();
  }

  static ThemeData build(String theme, {double fontScale = 1.0}) {
    final dark = theme == 'dark';
    final gold = theme == 'gold';
    final primary = dark ? const Color(0xFF55C4E5)
      : gold ? const Color(0xFF946B20) : const Color(0xFF087C9B);
    final background = dark ? const Color(0xFF0C1420)
      : gold ? const Color(0xFFFCF8EC) : const Color(0xFFF3F7FA);
    final surface = dark ? const Color(0xFF152334)
      : gold ? const Color(0xFFFFFEFA) : Colors.white;
    final base = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary, brightness: dark ? Brightness.dark : Brightness.light,
        surface: surface,
      ),
    );
    final textTheme = _scaledTextTheme(base.textTheme, 1.05 * _safeFontScale(fontScale));
    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background, surfaceTintColor: Colors.transparent,
        centerTitle: false, elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0, color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: primary.withValues(alpha: .12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: dark ? const Color(0xFF1D2E40)
          : gold ? const Color(0xFFF6EEDC) : const Color(0xFFE8F1F5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        indicatorColor: primary.withValues(alpha: .14),
        height: 72,
      ),
    );
  }
}
