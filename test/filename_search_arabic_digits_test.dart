import 'package:adnanload_mobile/core/download_list_filter.dart';
import 'package:adnanload_mobile/core/file_hub_filter.dart';
import 'package:adnanload_mobile/core/filename_search.dart';
import 'package:adnanload_mobile/models/download_entry.dart';
import 'package:flutter_test/flutter_test.dart';

DownloadEntry _entry(String name, {String path = '',
    String url = 'https://example.org/file', String status = 'complete'}) =>
    DownloadEntry(
      id: 'arabic-digit-search',
      url: url,
      name: name,
      kind: 'direct',
      status: status,
      path: path,
      addedAt: 1,
    );

void main() {
  test('filename search matches all three decimal digit scripts', () {
    expect(FilenameSearch.contains('الجزء١۲.pdf', 'الجزء12'), isTrue);
    expect(FilenameSearch.contains('الجزء12.pdf', 'الجزء١٢'), isTrue);
    expect(FilenameSearch.contains('الجزء۱۲.pdf', 'الجزء١2'), isTrue);
    expect(FilenameSearch.contains('الجزء12.pdf', 'الجزء13'), isFalse);
  });

  test('Downloads search folds digits while retaining status filters', () {
    final item = _entry('الحلقة ٢٠٢٦.mp4');
    expect(DownloadListFilter.matches(item,
        filter: 'finished', query: 'الحلقة 2026'), isTrue);
    expect(DownloadListFilter.matches(item,
        filter: 'finished', query: 'الحلقة ۲۰۲۶'), isTrue);
    expect(DownloadListFilter.matches(item,
        filter: 'active', query: 'الحلقة 2026'), isFalse);
  });

  test('Files search folds digits in display and stored basenames', () {
    final item = _entry('Episode ۱۲', path: '/private/مجلد/الحلقة_١٢.mp4');
    expect(FileHubFilter.matches(item,
        selected: 'videoFiles', query: 'episode 12'), isTrue);
    expect(FileHubFilter.matches(item,
        selected: 'videoFiles', query: 'الحلقة_12'), isTrue);
    expect(FileHubFilter.matches(item,
        selected: 'audioFiles', query: 'الحلقة_12'), isFalse);
    expect(FileHubFilter.matches(item,
        selected: 'all', query: 'مجلد'), isFalse);
  });

  test('signed URL query matching stays literal across digit scripts', () {
    final item = _entry('report.pdf',
        url: 'https://cdn.example.org/file?signature=١۲%2F');
    expect(DownloadListFilter.matches(item,
        filter: 'finished', query: 'signature=١۲%2F'), isTrue);
    expect(DownloadListFilter.matches(item,
        filter: 'finished', query: 'signature=12%2F'), isFalse);
    expect(DownloadListFilter.matches(item,
        filter: 'finished', query: 'signature=١۲/'), isFalse);
  });

  test('existing Arabic folding and ordinary ASCII searches still work', () {
    expect(FilenameSearch.contains('إعْلان الحلقة ١٠.MP4',
        'اعلان الحلقة 10.mp4'), isTrue);
    expect(FilenameSearch.contains('Holiday_2026.mp4',
        'holiday_٢٠٢٦'), isTrue);
    expect(FilenameSearch.contains('report.pdf', '\u064E\u0640'),
        isFalse);
  });
}
