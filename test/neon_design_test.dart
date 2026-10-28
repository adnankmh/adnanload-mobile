import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/app_strings.dart';
import 'package:adnanload_mobile/core/theme.dart';
import 'package:adnanload_mobile/screens/neon_home_page.dart';
import 'package:adnanload_mobile/services/download_repository.dart';

void main() {
  test('neon theme is present and preserves royal gold', () {
    expect(BrandThemes.names.contains('neon'), isTrue);
    expect(BrandThemes.names.contains('gold'), isTrue);
  });

  testWidgets('new home UI is wired to download callback, not a simulation',
      (tester) async {
    final repo = DownloadRepository();
    String? requested;
    String? mode;
    await tester.pumpWidget(MaterialApp(
      theme: BrandThemes.build('neon'),
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
