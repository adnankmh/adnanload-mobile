import 'dart:async';

import 'package:adnanload_mobile/core/app_strings.dart';
import 'package:adnanload_mobile/services/download_repository.dart';
import 'package:adnanload_mobile/widgets/settings_media_engine_tile.dart';
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

const _updateKey = Key('settings-media-engine-update');

Future<void> _showSettingsTile(WidgetTester tester, _FakeRepository repo,
    {String language = 'en'}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SettingsMediaEngineTile(
        repo: repo,
        strings: AppStrings(language),
      ),
    ),
  ));
}

void main() {
  testWidgets('settings prevents duplicate updates and shows progress',
      (tester) async {
    final pending = Completer<void>();
    final repo = _FakeRepository(() => pending.future);
    await _showSettingsTile(tester, repo);

    await tester.tap(find.byKey(_updateKey));
    await tester.pump();
    expect(repo.updateCalls, 1);
    expect(find.text('Updating'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<ListTile>(find.byKey(_updateKey)).onTap, isNull);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile))
        .onChanged, isNull);

    await tester.tap(find.byKey(_updateKey), warnIfMissed: false);
    await tester.pump();
    expect(repo.updateCalls, 1);

    pending.complete();
    await tester.pump();
    expect(find.text('Media engine updated'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byKey(_updateKey)).onTap, isNotNull);
    repo.dispose();
  });

  testWidgets('settings failure redacts signed URLs in Arabic',
      (tester) async {
    final pending = Completer<void>();
    final repo = _FakeRepository(() => pending.future);
    await _showSettingsTile(tester, repo, language: 'ar');

    await tester.tap(find.byKey(_updateKey));
    await tester.pump();
    pending.completeError(
      StateError('https://example.org/asset?token=private-secret'),
    );
    await tester.pump();

    expect(find.text('فشل تحديث المحرك'), findsOneWidget);
    expect(find.textContaining('private-secret'), findsNothing);
    expect(tester.widget<ListTile>(find.byKey(_updateKey)).onTap, isNotNull);
    repo.dispose();
  });

  testWidgets('settings ignores completion after navigation away',
      (tester) async {
    final pending = Completer<void>();
    final repo = _FakeRepository(() => pending.future);
    await _showSettingsTile(tester, repo);

    await tester.tap(find.byKey(_updateKey));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    pending.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
    repo.dispose();
  });

  testWidgets('automatic stable-channel setting remains available',
      (tester) async {
    final repo = _FakeRepository(() async {});
    await _showSettingsTile(tester, repo);
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isFalse);
    expect(toggle.onChanged, isNotNull);
    expect(find.text('Update media engine'), findsOneWidget);
    repo.dispose();
  });
}
