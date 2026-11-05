import 'dart:async';

import 'package:adnanload_mobile/core/app_strings.dart';
import 'package:adnanload_mobile/screens/media_page.dart';
import 'package:adnanload_mobile/services/download_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository extends DownloadRepository {
  _FakeRepository(this.performUpdate);
  final Future<void> Function() performUpdate;
  int updateCalls = 0;

  @override
  Future<void> updateMediaEngine() {
    updateCalls++;
    return performUpdate();
  }
}

Future<void> _showMedia(WidgetTester tester, _FakeRepository repo,
    {String language = 'en', void Function(String, String)? onAdd}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MediaPage(
        repo: repo,
        strings: AppStrings(language),
        onAdd: onAdd ?? (_, __) {},
      ),
    ),
  ));
  await tester.ensureVisible(find.byType(OutlinedButton));
}

void main() {
  testWidgets('only one update is dispatched while the request is pending',
      (tester) async {
    final pending = Completer<void>();
    final repo = _FakeRepository(() => pending.future);
    await _showMedia(tester, repo);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    expect(repo.updateCalls, 1);
    expect(find.text('Updating'), findsOneWidget);
    expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(OutlinedButton), warnIfMissed: false);
    await tester.pump();
    expect(repo.updateCalls, 1);

    pending.complete();
    await tester.pump();
    expect(find.text('Media engine updated'), findsOneWidget);
    expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull);
    repo.dispose();
  });

  testWidgets('failure is localized and never exposes exception URLs',
      (tester) async {
    final pending = Completer<void>();
    final repo = _FakeRepository(() => pending.future);
    await _showMedia(tester, repo, language: 'ar');

    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    pending.completeError(
        StateError('https://example.org/file?token=private-secret'));
    await tester.pump();

    expect(find.text('فشل تحديث المحرك'), findsOneWidget);
    expect(find.textContaining('private-secret'), findsNothing);
    expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull);
    repo.dispose();
  });

  testWidgets('completion after leaving media screen is ignored safely',
      (tester) async {
    final pending = Completer<void>();
    final repo = _FakeRepository(() => pending.future);
    await _showMedia(tester, repo);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    pending.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
    repo.dispose();
  });

  testWidgets('video, playlist and MP3 actions remain wired',
      (tester) async {
    final repo = _FakeRepository(() async {});
    final modes = <String>[];
    await _showMedia(tester, repo,
        onAdd: (url, mode) {
          expect(url, isEmpty);
          modes.add(mode);
        });

    for (final icon in [
      Icons.movie_creation_outlined,
      Icons.playlist_play_rounded,
      Icons.music_note_rounded,
    ]) {
      await tester.ensureVisible(find.byIcon(icon));
      await tester.tap(find.byIcon(icon));
      await tester.pump();
    }
    expect(modes, ['video', 'playlist', 'mp3']);
    repo.dispose();
  });
}
