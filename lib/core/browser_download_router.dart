import 'url_guard.dart';

/// Intercept only navigations to recognizable public HTTP(S) files.
///
/// Browser pages and streaming manifests remain in WebView, where the user
/// can explicitly choose the media extractor. The URL is never rewritten:
/// signed query parameters must reach the downloader unchanged.
class BrowserDownloadRouter {
  BrowserDownloadRouter._();

  static final RegExp _directFileExtension = RegExp(
    r'\.(?:zip|rar|7z|tar|gz|tgz|bz2|zst|apk|pdf|epub|mp3|m4a|wav|flac|ogg|opus|aac|mp4|mkv|webm|mov|avi|m4v|iso|exe|msi|deb|rpm|dmg|docx?|xlsx?|pptx?|txt|csv|rtf|png|jpe?g|gif|webp|bmp)$',
    caseSensitive: false,
  );

  static bool isDirectFileNavigation(String url) {
    final uri = UrlGuard.validate(url);
    if (uri == null) return false;
    // Uri.path excludes query strings and fragments, even for signed URLs.
    return _directFileExtension.hasMatch(uri.path);
  }
}
