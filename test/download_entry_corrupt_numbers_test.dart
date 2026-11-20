import 'dart:convert';

import 'package:adnanload_mobile/models/download_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> base() => {
    'id': 'persisted-1',
    'url': 'https://example.org/file.bin',
    'name': 'file.bin',
    'kind': 'direct',
    'status': 'paused',
    'addedAt': 123,
    'autoQueue': false,
    'nativeQueued': true,
  };

  test('malformed persisted numeric values do not discard a download', () {
    final item = DownloadEntry.fromJson({
      ...base(),
      'progress': 'not-a-number',
      'speed': double.nan,
      'addedAt': 'broken',
      'scheduledAt': double.infinity,
      'priority': 'high',
      'retryAttempts': double.negativeInfinity,
      'retryAt': 'later',
    });
    expect(item.id, 'persisted-1');
    expect(item.status, 'paused');
    expect(item.nativeQueued, isTrue);
    expect(item.autoQueue, isFalse);
    expect(item.progress, 0);
    expect(item.speed, 0);
    expect(item.addedAt, greaterThan(0));
    expect(item.scheduledAt, 0);
    expect(item.priority, 5);
    expect(item.retryAttempts, 0);
    expect(item.retryAt, 0);
  });

  test('finite values are bounded without changing valid history', () {
    final item = DownloadEntry.fromJson({
      ...base(),
      'progress': 2.5,
      'speed': -7,
      'addedAt': -1,
      'scheduledAt': -99,
      'priority': 99,
      'retryAttempts': 50,
      'retryAt': -4,
    });
    expect(item.progress, 1);
    expect(item.speed, 0);
    expect(item.addedAt, 0);
    expect(item.scheduledAt, 0);
    expect(item.priority, 10);
    expect(item.retryAttempts, 3);
    expect(item.retryAt, 0);
  });

  test('non-finite native metrics cannot break history JSON encoding', () {
    final item = DownloadEntry.fromJson({
      ...base(),
      'progress': 0.25,
      'speed': 12.5,
      'priority': 7,
      'retryAt': 400,
    });
    item.progress = double.nan;
    item.speed = double.infinity;
    final restored = DownloadEntry.fromJson(
      jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
    );
    expect(restored.progress, 0);
    expect(restored.speed, 0);
    expect(restored.status, 'paused');
    expect(restored.nativeQueued, isTrue);
    expect(restored.priority, 7);
    expect(restored.retryAt, 400);
  });

  test('valid numeric state still round trips unchanged', () {
    final item = DownloadEntry.fromJson({
      ...base(),
      'progress': 0.625,
      'speed': 2.75,
      'addedAt': 123,
      'scheduledAt': 500,
      'priority': 8,
      'retryAttempts': 2,
      'retryAt': 450,
    });
    final restored = DownloadEntry.fromJson(
      jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
    );
    expect(restored.progress, 0.625);
    expect(restored.speed, 2.75);
    expect(restored.addedAt, 123);
    expect(restored.scheduledAt, 500);
    expect(restored.priority, 8);
    expect(restored.retryAttempts, 2);
    expect(restored.retryAt, 450);
  });

  test('extreme persisted timestamps are capped at DateTime limits', () {
    const maxTimestamp = 8640000000000000;
    final item = DownloadEntry.fromJson({
      ...base(),
      'addedAt': maxTimestamp + 1,
      'scheduledAt': double.maxFinite,
      'retryAt': maxTimestamp + 1,
    });
    expect(item.addedAt, maxTimestamp);
    expect(item.scheduledAt, maxTimestamp);
    expect(item.retryAt, maxTimestamp);
  });

  test('mutated numeric fields are normalized on JSON export', () {
    final item = DownloadEntry.fromJson(base());
    item.progress = double.negativeInfinity;
    item.speed = -12;
    item.addedAt = -5;
    item.scheduledAt = 8640000000000001;
    item.retryAt = -100;
    item.priority = 99;
    item.retryAttempts = -7;

    final saved = jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>;
    expect(saved['progress'], 0);
    expect(saved['speed'], 0);
    expect(saved['addedAt'], 0);
    expect(saved['scheduledAt'], 8640000000000000);
    expect(saved['retryAt'], 0);
    expect(saved['priority'], 10);
    expect(saved['retryAttempts'], 0);
    expect(saved['nativeQueued'], isTrue);
  });
}
