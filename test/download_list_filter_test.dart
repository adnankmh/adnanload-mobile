import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/download_list_filter.dart';
import 'package:adnanload_mobile/models/download_entry.dart';

DownloadEntry entry(String status, {String name = 'Report.pdf',
    String url = 'https://example.org/Report.pdf',
    bool scheduledExternally = false}) => DownloadEntry(
  id: status,
  url: url,
  name: name,
  kind: 'direct',
  status: status,
  addedAt: 1,
  scheduledExternally: scheduledExternally,
);

void main() {
  test('active tab retains jobs during native submission and verification', () {
    for (final status in ['submitting', 'verifying', 'running', 'waiting', 'paused']) {
      expect(DownloadListFilter.matches(entry(status), filter: 'active', query: ''),
          isTrue, reason: status);
    }
  });

  test('active tab excludes terminal states', () {
    for (final status in ['complete', 'error', 'canceled']) {
      expect(DownloadListFilter.matches(entry(status), filter: 'active', query: ''),
          isFalse, reason: status);
    }
  });

  test('finished and failed chips retain existing status meanings', () {
    expect(DownloadListFilter.matches(entry('complete'), filter: 'finished',
        query: ''), isTrue);
    expect(DownloadListFilter.matches(entry('verifying'), filter: 'finished',
        query: ''), isFalse);
    for (final status in ['error', 'canceled']) {
      expect(DownloadListFilter.matches(entry(status), filter: 'failed',
          query: ''), isTrue);
    }
    expect(DownloadListFilter.matches(entry('submitting'), filter: 'failed',
        query: ''), isFalse);
  });

  test('scheduled Android waiting jobs remain visible as active', () {
    expect(DownloadListFilter.matches(entry('waiting',
        scheduledExternally: true), filter: 'active', query: ''), isTrue);
  });

  test('search matches name and URL case-insensitively and trims spaces', () {
    final item = entry('verifying', name: 'Holiday.MP4',
        url: 'https://example.org/media/123');
    expect(DownloadListFilter.matches(item, filter: 'active',
        query: '  HOLIDAY  '), isTrue);
    expect(DownloadListFilter.matches(item, filter: 'active',
        query: '  MEDIA/123  '), isTrue);
    expect(DownloadListFilter.matches(item, filter: 'active',
        query: 'missing'), isFalse);
  });

  test('all chip keeps existing behavior for unrecognized states', () {
    expect(DownloadListFilter.matches(entry('future-state'),
        filter: 'all', query: ''), isTrue);
    expect(DownloadListFilter.matches(entry('future-state'),
        filter: 'active', query: ''), isFalse);
  });

  test('Arabic filename search ignores vowel marks and alef variants', () {
    final item = entry('complete',
        name: 'إعْلان التـَّحميل النهائي.pdf');
    expect(DownloadListFilter.matches(item,
        filter: 'all', query: 'اعلان التحميل'), isTrue);
    expect(DownloadListFilter.matches(item,
        filter: 'all', query: 'إعْلان'), isTrue);
    expect(DownloadListFilter.matches(item,
        filter: 'all', query: 'غير موجود'), isFalse);
  });

  test('Arabic final alef maqsura and ordinary ya match in filenames', () {
    final item = entry('complete', name: 'هدى.pdf');
    expect(DownloadListFilter.matches(item,
        filter: 'finished', query: 'هدي'), isTrue);
    expect(DownloadListFilter.matches(item,
        filter: 'failed', query: 'هدي'), isFalse);
  });

  test('marks-only query does not match every filename', () {
    final item = entry('complete', name: 'report.pdf');
    for (final query in ['\u064E', '\u0640', '\u0670']) {
      expect(DownloadListFilter.matches(item,
          filter: 'all', query: query), isFalse, reason: query);
    }
  });

  test('signed URL search remains literal and percent encoding is preserved', () {
    final item = entry('complete', name: 'ملف.pdf',
        url: 'https://cdn.example.org/file?sig=AB%2FCD');
    expect(DownloadListFilter.matches(item,
        filter: 'all', query: 'AB%2FCD'), isTrue);
    expect(DownloadListFilter.matches(item,
        filter: 'all', query: 'AB/CD'), isFalse);
  });
}
