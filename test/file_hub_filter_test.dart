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
}
