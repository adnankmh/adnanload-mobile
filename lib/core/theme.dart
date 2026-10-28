import 'package:flutter/material.dart';

class BrandThemes {
  static const names = ['neon', 'gold', 'amoled', 'glass', 'midnight', 'emerald', 'dark', 'light'];

  /// Scale only concrete font sizes; Flutter may supply null fontSize styles.
  static TextTheme _scaledTextTheme(Brightness brightness, double factor) {
    final base = ThemeData(brightness: brightness).textTheme;
    TextStyle? scaled(TextStyle? style) => style?.copyWith(
      fontSize: (style.fontSize ?? 14.0) * factor,
    );
    return base.copyWith(
      displayLarge: scaled(base.displayLarge),
      displayMedium: scaled(base.displayMedium),
      displaySmall: scaled(base.displaySmall),
      headlineLarge: scaled(base.headlineLarge),
      headlineMedium: scaled(base.headlineMedium),
      headlineSmall: scaled(base.headlineSmall),
      titleLarge: scaled(base.titleLarge),
      titleMedium: scaled(base.titleMedium),
      titleSmall: scaled(base.titleSmall),
      bodyLarge: scaled(base.bodyLarge),
      bodyMedium: scaled(base.bodyMedium),
      bodySmall: scaled(base.bodySmall),
      labelLarge: scaled(base.labelLarge),
      labelMedium: scaled(base.labelMedium),
      labelSmall: scaled(base.labelSmall),
    );
  }

  static ThemeData build(String theme, {double fontScale = 1.0}) {
    final light = theme == 'light';
    final gold = theme == 'gold';
    final seed = switch (theme) {
      'neon' => const Color(0xFF00E5FF),
      'amoled' => const Color(0xFF00E5B6),
      'glass' => const Color(0xFF9D8BFF),
      'midnight' => const Color(0xFF4DABF7),
      'emerald' => const Color(0xFF5CCDA5),
      'light' => const Color(0xFF306DAB),
      'dark' => const Color(0xFF78A6FA),
      _ => const Color(0xFFF2C76A),
    };
    final bg = switch (theme) {
      'neon' => const Color(0xFF0B0F17),
      'gold' => const Color(0xFF080A0D),
      'amoled' => const Color(0xFF000000),
      'glass' => const Color(0xFF11111E),
      'midnight' => const Color(0xFF071424),
      'emerald' => const Color(0xFF081813),
      'dark' => const Color(0xFF0F141C),
      _ => const Color(0xFFF3F6FA),
    };
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: light ? Brightness.light : Brightness.dark);
    final neon = theme == 'neon';
    return ThemeData(
      useMaterial3: true,
      brightness: light ? Brightness.light : Brightness.dark,
      fontFamily: 'Roboto',
      colorScheme: scheme.copyWith(primary: seed, secondary: neon ? const Color(0xFF9D4EDD) : scheme.secondary,
        surface: light ? Colors.white : (neon ? const Color(0xFF151B28) : (gold ? const Color(0xFF12161C) : (theme=='amoled' ? const Color(0xFF090909) : const Color(0xFF15222C))))),
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(backgroundColor: bg, centerTitle: false, surfaceTintColor: Colors.transparent),
      cardTheme: CardThemeData(elevation: 0, color: light ? Colors.white : (neon ? const Color(0xFF161E2E) : (theme=='amoled' ? const Color(0xFF0B0B0B) : const Color(0xFF161C24))),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: seed.withValues(alpha: .17)))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: light ? const Color(0xFFF0F3F8) : (neon ? const Color(0xFF1C2436) : const Color(0xFF1D2530)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: neon ? const Color(0xFF101624) : bg,
        indicatorColor: seed.withValues(alpha: .20), height: 70),
      textTheme: _scaledTextTheme(light ? Brightness.light : Brightness.dark, 1.04 * fontScale),
    );
  }
}
