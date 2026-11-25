import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/download_list_filter.dart';
import 'package:adnanload_mobile/core/download_list_sort.dart';
import 'package:adnanload_mobile/models/download_entry.dart';

DownloadEntry job(String id, String status, {int at = 1, double progress = 0,
  double speed = 0, int scheduled = 0, int retry = 0}) => DownloadEntry(
    id: id, url: 'https://example.org/$id', name: '$id.zip', kind: 'direct',
    status: status, addedAt: at, progress: progress, speed: speed,
    scheduledAt: scheduled, retryAt: retry,
  );

void main() {
  bool matches(DownloadEntry e, String filter, [String query = '']) =>
      DownloadListFilter.matches(e, filter: filter, query: query);

  test('detailed status chips preserve lifecycle and search semantics', () {
    final queued = job('queued', 'waiting', scheduled: 100, retry: 200);
    expect(matches(queued, 'waiting'), isTrue);
    expect(matches(queued, 'scheduled'), isTrue);
    expect(matches(queued, 'retrying'), isTrue);
    expect(matches(queued, 'scheduled', 'absent'), isFalse);
    expect(matches(queued, 'scheduled', 'queued.zip'), isTrue);
    for (final status in ['paused', 'running', 'complete', 'error',
        'canceled', 'submitting', 'verifying']) {
      final entry = job(status, status, scheduled: 100, retry: 200);
      expect(matches(entry, 'scheduled'), isFalse, reason: status);
      expect(matches(entry, 'retrying'), isFalse, reason: status);
      expect(matches(entry, 'waiting'), isFalse, reason: status);
    }
    expect(matches(job('p', 'paused'), 'paused'), isTrue);
    expect(matches(job('r', 'running'), 'running'), isTrue);
    expect(matches(job('v', 'verifying'), 'verifying'), isTrue);
    expect(matches(job('v', 'submitting'), 'verifying'), isFalse);
    expect(matches(job('n', 'waiting', scheduled: -1, retry: -1),
        'scheduled'), isFalse);
    expect(matches(job('n', 'waiting'), 'retrying'), isFalse);
  });

  test('progress sort handles completed, corrupt and bounded progress', () {
    final entries = [
      job('nan', 'running', progress: double.nan),
      job('half', 'paused', progress: .5),
      job('done', 'complete', at: 4),
      job('negative', 'waiting', progress: -1),
      job('over', 'running', at: 2, progress: 1.5),
    ];
    expect(DownloadListSort.ordered(entries, 'progress').map((e) => e.id),
        ['done', 'over', 'half', 'nan', 'negative']);
    expect(entries.first.progress.isNaN, isTrue);
    expect(entries.last.progress, 1.5);
  });

  test('speed sort ignores stale and invalid rates without changing jobs', () {
    final entries = [
      job('paused', 'paused', speed: 100, at: 3),
      job('slow', 'running', speed: 1),
      job('fast', 'running', speed: 10),
      job('invalid', 'running', speed: double.infinity, at: 2),
      job('negative', 'running', speed: -2),
    ];
    expect(DownloadListSort.ordered(entries, 'speed').map((e) => e.id),
        ['fast', 'slow', 'paused', 'invalid', 'negative']);
    expect(entries.first.speed, 100);
    expect(entries.map((e) => e.id),
        ['paused', 'slow', 'fast', 'invalid', 'negative']);
  });

  test('new options have Arabic and English labels', () {
    expect(DownloadListSort.label('progress', arabic: false), 'Highest progress');
    expect(DownloadListSort.label('speed', arabic: false), 'Fastest transfer');
    expect(DownloadListSort.label('progress', arabic: true), 'الأعلى تقدمًا');
    expect(DownloadListSort.label('speed', arabic: true), 'الأسرع تحميلًا');
    expect(DownloadListFilter.label('verifying', arabic: false), 'Verifying');
    expect(DownloadListFilter.filters.toSet().length,
        DownloadListFilter.filters.length);
  });
}
