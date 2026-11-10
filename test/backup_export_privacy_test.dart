import 'dart:convert';

import 'package:adnanload_mobile/models/download_entry.dart';
import 'package:adnanload_mobile/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DownloadEntry activeEntry() => DownloadEntry(
    id: 'native-task-123',
    url: 'https://example.org/archive.zip?token=keep-for-restore',
    name: 'archive.zip',
    kind: 'direct',
    status: 'running',
    addedAt: 12345,
    path: '/data/user/0/private-device-path/archive.zip',
    error: 'private-error-marker /data/user/0/private-device-path',
    actualSha256: 'private-actual-hash-marker',
    expectedSha256: 'a' * 64,
    autoQueue: true,
    nativeQueued: true,
    scheduledExternally: true,
    scheduledAt: 20000,
    retryAttempts: 2,
    retryAt: 30000,
    priority: 7,
    progress: 0.62,
    speed: 2048.0,
  );

  Map<String, dynamic> export(DownloadEntry entry) => BackupService.create(
    items: [entry],
    bookmarks: ['https://example.org/bookmark'],
    theme: 'gold',
    language: 'ar',
    wifiOnly: true,
  );

  test('portable JSON never exposes local paths, errors or actual hashes', () {
    final entry = activeEntry();
    final backup = export(entry);
    final serialized = jsonEncode(backup);
    expect(serialized, isNot(contains('private-device-path')));
    expect(serialized, isNot(contains('private-error-marker')));
    expect(serialized, isNot(contains('private-actual-hash-marker')));
    expect(serialized, isNot(contains('native-task-123')));

    final record = (backup['history'] as List).single as Map<String, dynamic>;
    expect(record['id'], '');
    expect(record['status'], 'waiting');
    expect(record['progress'], 0.0);
    expect(record['speed'], 0.0);
    expect(record['path'], '');
    expect(record['error'], '');
    expect(record['actualSha256'], '');
    expect(record['nativeQueued'], false);
    expect(record['scheduledExternally'], false);
    expect(record['autoQueue'], false);
    expect(record['scheduledAt'], 0);
    expect(record['retryAt'], 0);
    expect(record['retryAttempts'], 0);
    expect(record['url'], entry.url);
    expect(record['expectedSha256'], entry.expectedSha256);
    expect(record['priority'], 7);
    expect(backup['preferences'], {
      'theme': 'gold',
      'language': 'ar',
      'wifiOnly': true,
    });
  });

  test('export does not mutate the running task in local history', () {
    final entry = activeEntry();
    export(entry);
    expect(entry.id, 'native-task-123');
    expect(entry.status, 'running');
    expect(entry.progress, 0.62);
    expect(entry.speed, 2048.0);
    expect(entry.path, '/data/user/0/private-device-path/archive.zip');
    expect(entry.error, contains('private-error-marker'));
    expect(entry.actualSha256, 'private-actual-hash-marker');
    expect(entry.nativeQueued, isTrue);
    expect(entry.autoQueue, isTrue);
    expect(entry.scheduledExternally, isTrue);
    expect(entry.scheduledAt, 20000);
    expect(entry.retryAt, 30000);
  });

  test('completed jobs also export as inert, portable history', () {
    final completed = DownloadEntry.fromJson({
      ...activeEntry().toJson(),
      'id': 'native-completed-secret',
      'status': 'completed',
      'progress': 1.0,
      'speed': 4096.0,
    });
    final record = (export(completed)['history'] as List).single
        as Map<String, dynamic>;
    expect(record['id'], '');
    expect(record['status'], 'waiting');
    expect(record['progress'], 0.0);
    expect(record['speed'], 0.0);
    expect(completed.id, 'native-completed-secret');
    expect(completed.status, 'completed');
    expect(completed.progress, 1.0);
  });

  test('sanitized backups restore without restarting native work', () {
    final backup = BackupService.parse(jsonEncode(export(activeEntry())));
    final restored = BackupService.validEntries(backup);
    expect(restored, hasLength(1));
    final item = restored.single;
    expect(item.id, isNot('native-task-123'));
    expect(item.status, 'waiting');
    expect(item.path, isEmpty);
    expect(item.error, isEmpty);
    expect(item.actualSha256, isEmpty);
    expect(item.autoQueue, isFalse);
    expect(item.nativeQueued, isFalse);
    expect(item.scheduledExternally, isFalse);
    expect(item.scheduledAt, 0);
    expect(item.retryAt, 0);
    expect(item.url, activeEntry().url);
    expect(item.expectedSha256, 'a' * 64);
  });
}
