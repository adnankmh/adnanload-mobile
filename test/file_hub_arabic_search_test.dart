import 'package:adnanload_mobile/core/download_list_filter.dart';
import 'package:adnanload_mobile/core/file_hub_filter.dart';
import 'package:adnanload_mobile/core/filename_search.dart';
import 'package:adnanload_mobile/models/download_entry.dart';
import 'package:flutter_test/flutter_test.dart';

DownloadEntry _entry(String name, {String path = '',
    String url = 'https://example.org/file'}) => DownloadEntry(
  id: 'file',
  url: url,
  name: name,
  kind: 'direct',
  status: 'complete',
  path: path,
  addedAt: 1,
);

void main() {
  test('Files search folds Arabic diacritics, tatweel and alef variants', () {
    final item = _entry('إعْلان التـَّحميل النهائي.pdf');
    expect(FileHubFilter.matches(item, selected: 'documentFiles',
        query: 'اعلان التحميل'), isTrue);
    expect(FileHubFilter.matches(item, selected: 'documentFiles',
        query: 'إعْلان'), isTrue);
    expect(FileHubFilter.matches(item, selected: 'documentFiles',
        query: 'غير موجود'), isFalse);
  });

  test('Files search folds saved basename when display name differs', () {
    final item = _entry('My document',
        path: '/storage/emulated/0/Download/هُدَى.PDF');
    expect(FileHubFilter.matches(item, selected: 'documentFiles',
        query: 'هدي'), isTrue);
    expect(FileHubFilter.matches(item, selected: 'documentFiles',
        query: 'هُدَى'), isTrue);
    expect(FileHubFilter.matches(item, selected: 'audioFiles',
        query: 'هدي'), isFalse);
  });

  test('Marks-only and elongation-only queries never match all files', () {
    final item = _entry('report.pdf', path: '/files/other.pdf');
    for (final query in ['\u064E', '\u0640', '\u0670', ' \u064E ']) {
      expect(FilenameSearch.contains(item.name, query), isFalse,
          reason: query);
      expect(FileHubFilter.matches(item, selected: 'all', query: query),
          isFalse, reason: query);
    }
  });

  test('Files search never reveals matches from parent folder names', () {
    final item = _entry('report.pdf',
        path: '/private/إعْلان/annual.pdf');
    expect(FileHubFilter.matches(item, selected: 'all',
        query: 'اعلان'), isFalse);
    expect(FileHubFilter.matches(item, selected: 'all',
        query: 'annual'), isTrue);
  });

  test('Downloads retains literal signed URL matching after reuse', () {
    final item = _entry('ملف.pdf',
        url: 'https://cdn.example.org/file?sig=AB%2FCD');
    expect(DownloadListFilter.matches(item, filter: 'finished',
        query: 'AB%2FCD'), isTrue);
    expect(DownloadListFilter.matches(item, filter: 'finished',
        query: 'AB/CD'), isFalse);
    expect(DownloadListFilter.matches(item, filter: 'finished',
        query: 'ملف'), isTrue);
  });

  test('ASCII search remains case-insensitive for both file tabs', () {
    final item = _entry('Holiday.MP4', path: '/files/CLIP.MP4');
    expect(FileHubFilter.matches(item, selected: 'videoFiles',
        query: 'holiday'), isTrue);
    expect(FileHubFilter.matches(item, selected: 'videoFiles',
        query: 'clip'), isTrue);
    expect(DownloadListFilter.matches(item, filter: 'finished',
        query: 'HOLIDAY'), isTrue);
  });
}
