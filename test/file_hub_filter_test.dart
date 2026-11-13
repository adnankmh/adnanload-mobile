import 'package:adnanload_mobile/core/file_hub_filter.dart';
import 'package:adnanload_mobile/models/download_entry.dart';
import 'package:flutter_test/flutter_test.dart';

DownloadEntry entry(String name, {String path = ''}) => DownloadEntry(
  id: 'test',
  url: 'https://example.org/download',
  name: name,
  kind: 'direct',
  status: 'complete',
  path: path,
  addedAt: 1,
);

void main() {
  test('keeps established video, audio and document categories', () {
    expect(FileHubFilter.matches(entry('clip.mp4'), selected: 'videoFiles'), isTrue);
    expect(FileHubFilter.matches(entry('voice.mp3'), selected: 'audioFiles'), isTrue);
    expect(FileHubFilter.matches(entry('report.pdf'), selected: 'documentFiles'), isTrue);
    expect(FileHubFilter.matches(entry('clip.mp4'), selected: 'audioFiles'), isFalse);
  });

  test('Files tab supports the same additional formats as SmartLink', () {
    expect(FileHubFilter.matches(entry('film.M4V'), selected: 'videoFiles'), isTrue);
    expect(FileHubFilter.matches(entry('voice.AAC'), selected: 'audioFiles'), isTrue);
    expect(FileHubFilter.matches(entry('letter.RTF'), selected: 'documentFiles'), isTrue);
  });

  test('uses the saved filename when display title lacks an extension', () {
    final item = entry('My holiday', path: '/storage/emulated/0/Download/holiday.mp4');
    expect(FileHubFilter.category(item), 'video');
    expect(FileHubFilter.matches(item, selected: 'videoFiles'), isTrue);
    expect(FileHubFilter.matches(item, selected: 'otherFiles'), isFalse);
  });

  test('saved file type takes precedence over an outdated display title', () {
    final item = entry('draft.pdf', path: r'C:\Downloads\final.mp3');
    expect(FileHubFilter.category(item), 'audio');
    expect(FileHubFilter.matches(item, selected: 'documentFiles'), isFalse);
  });

  test('falls back to the title for opaque storage paths', () {
    final item = entry('manual.docx', path: 'content://downloads/document/172');
    expect(FileHubFilter.matches(item, selected: 'documentFiles'), isTrue);
  });

  test('searches both displayed and saved basenames without exposing folders', () {
    final item = entry('My holiday', path: '/private/archive/holiday.MP4');
    expect(FileHubFilter.matches(item, selected: 'all', query: ' HOLIDAY '), isTrue);
    expect(FileHubFilter.matches(item, selected: 'videoFiles', query: '.mp4'), isTrue);
    expect(FileHubFilter.matches(item, selected: 'all', query: 'private'), isFalse);
  });

  test('SAF document IDs decode filenames without searching parent folders', () {
    final item = entry('Holiday', path:
        'content://com.android.externalstorage.documents/document/primary%3APrivate%2FMy%20Clip.MP4?token=secret#note');
    expect(FileHubFilter.category(item), 'video');
    expect(FileHubFilter.matches(item, selected: 'videoFiles',
        query: 'my clip'), isTrue);
    for (final query in ['private', 'primary', 'secret', 'note']) {
      expect(FileHubFilter.matches(item, selected: 'all', query: query),
          isFalse, reason: query);
    }
  });

  test('SAF root files and opaque IDs preserve category fallback', () {
    final root = entry('Untitled', path:
        'content://com.android.externalstorage.documents/document/primary%3AReport.pdf');
    expect(FileHubFilter.category(root), 'document');
    expect(FileHubFilter.matches(root, selected: 'all', query: 'primary'),
        isFalse);
    final opaque = entry('manual.docx', path:
        'content://downloads/document/172?name=clip.mp4');
    expect(FileHubFilter.category(opaque), 'document');
    expect(FileHubFilter.matches(opaque, selected: 'all', query: 'clip'),
        isFalse);
  });

  test('literal filesystem names are not URI decoded', () {
    final item = entry('Untitled', path: '/storage/clip%20name.mp4');
    expect(FileHubFilter.matches(item, selected: 'all', query: 'clip%20name'),
        isTrue);
    expect(FileHubFilter.matches(item, selected: 'all', query: 'clip name'),
        isFalse);
  });

  test('other files include images, archives, apps and unknown formats', () {
    for (final name in ['image.png', 'bundle.zip', 'installer.apk', 'raw.unknown']) {
      expect(FileHubFilter.matches(entry(name), selected: 'otherFiles'), isTrue,
          reason: name);
    }
    for (final name in ['clip.mp4', 'audio.mp3', 'book.pdf']) {
      expect(FileHubFilter.matches(entry(name), selected: 'otherFiles'), isFalse,
          reason: name);
    }
  });

  test('unknown selection retains the prior show-all fallback', () {
    expect(FileHubFilter.matches(entry('file.txt'), selected: 'unexpected'), isTrue);
  });

  test('supports Arabic names and case-insensitive saved-file search', () {
    final item = entry('تقرير العمليات', path: '/storage/Download/REPORT_2026.PDF');
    expect(FileHubFilter.matches(item, selected: 'documentFiles', query: 'تقرير'), isTrue);
    expect(FileHubFilter.matches(item, selected: 'documentFiles', query: 'report_2026'), isTrue);
    expect(FileHubFilter.matches(item, selected: 'audioFiles', query: 'report_2026'), isFalse);
  });

  test('recognizes extension on disk when the display title is empty', () {
    final item = entry('', path: r'C:\Downloads\capture.M4V');
    expect(FileHubFilter.category(item), 'video');
    expect(FileHubFilter.matches(item, selected: 'videoFiles', query: 'CAPTURE'), isTrue);
  });
}
