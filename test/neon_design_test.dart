import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/app_strings.dart';
import 'package:adnanload_mobile/core/theme.dart';
import 'package:adnanload_mobile/screens/neon_home_page.dart';
import 'package:adnanload_mobile/services/download_repository.dart';

void main() {
  test('exactly three themes including light gold', () {
    expect(BrandThemes.names, ['dark','light','gold']);
    expect(BrandThemes.build('gold').brightness, Brightness.light);
    expect(BrandThemes.names.contains('gold'), isTrue);
  });

  test('all three palettes scale typography without null-fontSize assertions', () {
    for (final palette in BrandThemes.names) {
      for (final scale in [0.9, 1.0, 1.35]) {
        final theme = BrandThemes.build(palette, fontScale: scale);
        expect(theme.textTheme.bodyMedium?.fontSize, greaterThan(0));
        expect(theme.textTheme.displayLarge?.fontSize, greaterThan(0));
        expect(theme.brightness, palette == 'dark' ? Brightness.dark : Brightness.light);
      }
    }
    expect(
      BrandThemes.build('dark', fontScale: 1.35).textTheme.bodyMedium!.fontSize!,
      greaterThan(BrandThemes.build('dark', fontScale: 0.9).textTheme.bodyMedium!.fontSize!),
    );
  });

  testWidgets('new home UI is wired to download callback, not a simulation',
      (tester) async {
    final repo = DownloadRepository();
    String? requested;
    String? mode;
    await tester.pumpWidget(MaterialApp(
      theme: BrandThemes.build('dark'),
      home: Scaffold(body: NeonHomePage(
        repo: repo, strings: const AppStrings('en'),
        onDownload: (url, kind) { requested = url; mode = kind; },
        onSeeAll: () {},
      )),
    ));
    expect(find.text('Active Downloads'), findsOneWidget);
    expect(find.text('No downloads yet'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'https://example.com/video');
    await tester.tap(find.text('Download').first);
    await tester.pump();
    expect(requested, 'https://example.com/video');
    expect(mode, 'direct'); // Generic HTTP files use the direct downloader.
    await tester.enterText(find.byType(TextField).first, 'https://www.youtube.com/watch?v=someVideo');
    await tester.tap(find.text('Download').first);
    await tester.pump();
    expect(mode, 'video');
    repo.dispose();
  });
}
