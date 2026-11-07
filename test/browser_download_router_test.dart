import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/browser_download_router.dart';

void main() {
  test('keeps all previously intercepted file extensions', () {
    for (final extension in [
      'zip', 'rar', '7z', 'tar', 'gz', 'apk', 'pdf', 'epub',
      'mp3', 'm4a', 'mp4', 'mkv', 'webm', 'iso', 'exe',
      'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    ]) {
      expect(
        BrowserDownloadRouter.isDirectFileNavigation(
          'https://cdn.example.com/archive.$extension'),
        isTrue,
        reason: extension,
      );
    }
  });

  test('intercepts additional downloadable media and archives', () {
    for (final extension in [
      'wav', 'flac', 'ogg', 'opus', 'aac', 'mov', 'avi', 'm4v',
      'msi', 'deb', 'rpm', 'dmg', 'tgz', 'bz2', 'zst',
    ]) {
      expect(
        BrowserDownloadRouter.isDirectFileNavigation(
          'https://files.example.com/dl/FILE.$extension'),
        isTrue,
        reason: extension,
      );
    }
  });

  test('signed queries, fragments and uppercase extensions remain valid', () {
    expect(
      BrowserDownloadRouter.isDirectFileNavigation(
        'https://cdn.example.com/archive.ZIP?signature=a%2Fb%3Dc;expires=42#view'),
      isTrue,
    );
    expect(
      BrowserDownloadRouter.isDirectFileNavigation(
        'https://cdn.example.com/movie%2EMP4?token=a%26b'),
      isTrue,
    );
  });

  test('inline-viewable image and text links stay in WebView', () {
    for (final extension in [
      'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'txt', 'csv', 'rtf',
    ]) {
      expect(
        BrowserDownloadRouter.isDirectFileNavigation(
          'https://cdn.example.com/preview.$extension?download=0'),
        isFalse,
        reason: extension,
      );
    }
    // Encoded extensions and signed query parameters cannot bypass this.
    expect(
      BrowserDownloadRouter.isDirectFileNavigation(
        'https://cdn.example.com/photo%2EJPEG?signature=a%2Fb'),
      isFalse,
    );
    expect(
      BrowserDownloadRouter.isDirectFileNavigation(
        'https://cdn.example.com/report%2ECSV?token=a%26b'),
      isFalse,
    );
  });

  test('web pages, opaque links and stream manifests are not intercepted', () {
    for (final url in [
      'https://example.com/watch?v=video.mp4',
      'https://example.com/download?id=report.pdf',
      'https://example.com/file.pdf/view',
      'https://example.com/live.m3u8',
      'https://example.com/live.mpd',
      'https://example.com/',
      'https://example.com/download.php?file=archive.zip',
    ]) {
      expect(BrowserDownloadRouter.isDirectFileNavigation(url), isFalse,
          reason: url);
    }
  });

  test('invalid, private and non-http destinations are never intercepted', () {
    for (final url in [
      'file:///sdcard/photo.jpg',
      'javascript:alert(1)',
      'https://localhost/private.pdf',
      'http://127.0.0.1/local.zip',
      'https://192.168.1.1/image.png',
      'https://user:password@example.com/archive.zip',
      'https://example.com.evil.local/file.mp4',
    ]) {
      expect(BrowserDownloadRouter.isDirectFileNavigation(url), isFalse,
          reason: url);
    }
  });

  test('embedded frame links never trigger automatic native downloads', () {
    const url = 'https://cdn.example.com/guide.pdf?token=valid';
    expect(BrowserDownloadRouter.isDirectFileNavigation(
      url, isMainFrame: false), isFalse);
    expect(BrowserDownloadRouter.isDirectFileNavigation(
      url, isMainFrame: true), isTrue);
  });
}
