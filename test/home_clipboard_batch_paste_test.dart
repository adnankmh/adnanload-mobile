import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/app_strings.dart';
import 'package:adnanload_mobile/screens/neon_home_page.dart';
import 'package:adnanload_mobile/services/download_repository.dart';

void _mockClipboard(String? text) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') {
      return text == null ? null : <String, dynamic>{'text': text};
    }
    return null;
  });
}

Future<void> _mountHome(WidgetTester tester, DownloadRepository repo,
    {ValueChanged<String>? onBatchPaste}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: NeonHomePage(
      repo: repo,
      strings: const AppStrings('en'),
      onDownload: (_, __) {},
      onSeeAll: () {},
      onBatchPaste: onBatchPaste,
    )),
  ));
}

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('explicit paste routes multiple distinct public links to batch',
      (tester) async {
    _mockClipboard('''
https://example.org/one.zip
https://example.org/one.zip#chapter
http://127.0.0.1/private
file:///etc/passwd
https://example.org/two.pdf
''');
    final repo = DownloadRepository();
    String? batch;
    await _mountHome(tester, repo, onBatchPaste: (value) => batch = value);
    await tester.tap(find.byTooltip('Paste'));
    await tester.pump();
    expect(batch, 'https://example.org/one.zip\nhttps://example.org/two.pdf');
    expect(tester.widget<TextField>(find.byType(TextField).first)
        .controller!.text, isEmpty);
    repo.dispose();
  });

  testWidgets('single public URL is pasted into the editable link field',
      (tester) async {
    _mockClipboard('Download: https://example.org/file.zip');
    final repo = DownloadRepository();
    String? batch;
    await _mountHome(tester, repo, onBatchPaste: (value) => batch = value);
    await tester.tap(find.byTooltip('Paste'));
    await tester.pump();
    expect(batch, isNull);
    expect(tester.widget<TextField>(find.byType(TextField).first)
        .controller!.text, 'https://example.org/file.zip');
    repo.dispose();
  });

  testWidgets('unsafe or non-URL clipboard text stays editable, not queued',
      (tester) async {
    const input = 'file:///etc/passwd http://localhost/admin';
    _mockClipboard(input);
    final repo = DownloadRepository();
    String? batch;
    await _mountHome(tester, repo, onBatchPaste: (value) => batch = value);
    await tester.tap(find.byTooltip('Paste'));
    await tester.pump();
    expect(batch, isNull);
    expect(tester.widget<TextField>(find.byType(TextField).first)
        .controller!.text, input);
    repo.dispose();
  });

  testWidgets('existing embedders without batch callback retain paste behavior',
      (tester) async {
    const input = 'https://example.org/a\nhttps://example.org/b';
    _mockClipboard(input);
    final repo = DownloadRepository();
    await _mountHome(tester, repo);
    await tester.tap(find.byTooltip('Paste'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).first)
        .controller!.text, input);
    repo.dispose();
  });
}
