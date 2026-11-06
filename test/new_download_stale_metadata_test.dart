import 'dart:async';

import 'package:adnanload_mobile/core/app_strings.dart';
import 'package:adnanload_mobile/services/download_repository.dart';
import 'package:adnanload_mobile/widgets/new_download_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControlledRepository extends DownloadRepository {
  final titleRequests = <Completer<String?>>[];
  final previewRequests = <Completer<MediaSnapshot?>>[];

  @override
  Future<String?> suggestMediaTitle(String url) {
    final request = Completer<String?>();
    titleRequests.add(request);
    return request.future;
  }

  @override
  Future<MediaSnapshot?> inspectMedia(String url) {
    final request = Completer<MediaSnapshot?>();
    previewRequests.add(request);
    return request.future;
  }
}

MediaSnapshot _snapshot(String title) => MediaSnapshot(
  title: title,
  uploader: 'Public uploader',
  thumbnail: '',
  durationSeconds: 12,
  formats: 2,
);

Future<void> _showSheet(WidgetTester tester, _ControlledRepository repo) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: NewDownloadSheet(
        repo: repo,
        strings: const AppStrings('en'),
        initialUrl: 'https://example.com/first',
        initialKind: 'video',
      ),
    ),
  ));
  await tester.pump(); // Run the initial post-frame title lookup.
}

void main() {
  testWidgets('editing URL rejects an older filename suggestion', (tester) async {
    final repo = _ControlledRepository();
    await _showSheet(tester, repo);
    expect(repo.titleRequests, hasLength(1));

    await tester.enterText(
      find.byType(TextField).first, 'https://example.com/second');
    repo.titleRequests.single.complete('Old video title');
    await tester.pump();

    final name = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(name.controller!.text, isNot(contains('Old video title')));
  });

  testWidgets('editing URL clears and rejects an in-flight preview', (tester) async {
    final repo = _ControlledRepository();
    await _showSheet(tester, repo);
    repo.titleRequests.single.complete(null);
    await tester.pump();

    final previewButton = find.text('Preview media details');
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pump();
    expect(repo.previewRequests, hasLength(1));

    await tester.enterText(
      find.byType(TextField).first, 'https://example.com/another');
    repo.previewRequests.single.complete(_snapshot('Stale preview'));
    await tester.pump();

    expect(find.text('Stale preview'), findsNothing);
  });

  testWidgets('current media preview still updates the UI', (tester) async {
    final repo = _ControlledRepository();
    await _showSheet(tester, repo);
    repo.titleRequests.single.complete(null);
    await tester.pump();

    final previewButton = find.text('Preview media details');
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pump();

    repo.previewRequests.single.complete(_snapshot('Current preview'));
    await tester.pump();

    expect(find.text('Current preview'), findsOneWidget);
    final name = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(name.controller!.text, 'Current preview.mp4');
  });

  testWidgets('failed preview shows retryable error without a stuck spinner', (tester) async {
    final repo = _ControlledRepository();
    await _showSheet(tester, repo);
    repo.titleRequests.single.complete(null);
    await tester.pump();

    final previewButton = find.text('Preview media details');
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pump();
    expect(repo.previewRequests, hasLength(1));

    repo.previewRequests.single.completeError(StateError('offline'));
    await tester.pump();

    expect(find.text('Could not fetch media information for this URL'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.ancestor(of: previewButton, matching: find.byType(OutlinedButton)));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('failed title suggestion keeps the existing name and clears loading', (tester) async {
    final repo = _ControlledRepository();
    await _showSheet(tester, repo);
    expect(repo.titleRequests, hasLength(1));

    final before = tester.widget<TextField>(find.byType(TextField).at(1))
        .controller!.text;
    repo.titleRequests.single.completeError(StateError('offline'));
    await tester.pump();

    final name = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(name.controller!.text, before);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('stale failed preview does not show an error for the new URL', (tester) async {
    final repo = _ControlledRepository();
    await _showSheet(tester, repo);
    repo.titleRequests.single.complete(null);
    await tester.pump();

    final previewButton = find.text('Preview media details');
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pump();

    await tester.enterText(
      find.byType(TextField).first, 'https://example.com/new-url');
    repo.previewRequests.single.completeError(StateError('obsolete'));
    await tester.pump();

    expect(find.text('Could not fetch media information for this URL'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
