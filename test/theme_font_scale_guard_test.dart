import 'package:adnanload_mobile/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final textSlots = <TextStyle? Function(TextTheme)>[
    (text) => text.displayLarge,
    (text) => text.displayMedium,
    (text) => text.displaySmall,
    (text) => text.headlineLarge,
    (text) => text.headlineMedium,
    (text) => text.headlineSmall,
    (text) => text.titleLarge,
    (text) => text.titleMedium,
    (text) => text.titleSmall,
    (text) => text.bodyLarge,
    (text) => text.bodyMedium,
    (text) => text.bodySmall,
    (text) => text.labelLarge,
    (text) => text.labelMedium,
    (text) => text.labelSmall,
  ];

  test('invalid zoom values recover to the default in all three themes', () {
    for (final palette in BrandThemes.names) {
      final baseline = BrandThemes.build(palette, fontScale: 1.0);
      for (final invalid in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        0.0,
        -3.0,
      ]) {
        final recovered = BrandThemes.build(palette, fontScale: invalid);
        expect(recovered.brightness, baseline.brightness);
        for (final slot in textSlots) {
          final actual = slot(recovered.textTheme)!.fontSize!;
          expect(actual, slot(baseline.textTheme)!.fontSize);
          expect(actual.isFinite, isTrue);
          expect(actual, greaterThan(0));
        }
      }
    }
  });

  test('finite zoom is bounded without changing supported zoom values', () {
    for (final palette in BrandThemes.names) {
      double size(double zoom) => BrandThemes.build(
        palette, fontScale: zoom,
      ).textTheme.bodyMedium!.fontSize!;

      expect(size(0.01), size(0.9));
      expect(size(99), size(1.35));
      expect(size(1.2), greaterThan(size(1.0)));
      expect(size(1.2), lessThan(size(1.35)));
    }
  });

  test('zoom changes typography without changing any palette colors', () {
    for (final palette in BrandThemes.names) {
      final baseline = BrandThemes.build(palette);
      for (final zoom in <double>[
        double.nan,
        double.infinity,
        -1.0,
        0.9,
        1.35,
        100.0,
      ]) {
        final themed = BrandThemes.build(palette, fontScale: zoom);
        expect(themed.useMaterial3, isTrue);
        expect(themed.brightness, baseline.brightness);
        expect(themed.colorScheme.primary, baseline.colorScheme.primary);
        expect(themed.colorScheme.surface, baseline.colorScheme.surface);
        expect(themed.scaffoldBackgroundColor, baseline.scaffoldBackgroundColor);
        expect(themed.cardTheme.color, baseline.cardTheme.color);
        expect(themed.appBarTheme.backgroundColor, baseline.appBarTheme.backgroundColor);
      }
    }
  });
}
