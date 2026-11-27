/// Only display predefined user-safe messages. Never show extractor logs,
/// tokens, cookies, or private signed URLs in the downloads UI.
class MediaFailure {
  // Recognize extractor and HTTP client status formats without mistaking
  // unrelated numbers in a signed URL or a filename for an HTTP response.
  static bool _hasHttpStatus(String text, Set<int> statuses) =>
      RegExp(
        r'\b(?:http(?:/\d+(?:\.\d+)?)?(?:\s+(?:error|status(?:\s+code)?))?|status(?:\s+code)?)\s*[:=]?\s*(\d{3})\b',
      ).allMatches(text).any(
        (match) => statuses.contains(int.parse(match.group(1)!)),
      );

  static String classify(String reason) {
    final text = reason.toLowerCase();
    // A combined extractor log can mention both DRM and an HTTP 403. Keep
    // the protected-content explanation authoritative: never suggest that
    // signing in or retrying could bypass a protected stream.
    if (RegExp(r'\b(drm|widevine)\b|protected content').hasMatch(text)) {
      return 'mediaProtected';
    }
    // Storage failures take priority over incidental network errors in a
    // multi-line report; retrying would only repeat the failed write.
    if (RegExp(r'(no space left|disk full|enospc|insufficient storage)').hasMatch(text)) {
      return 'mediaStorageFull';
    }
    if (RegExp(r'(sign in to confirm|confirm you.re not a bot|unusual traffic|automated requests|captcha|verify you are human)').hasMatch(text)) {
      return 'mediaVerificationRequired';
    }
    if (_hasHttpStatus(text, const {401, 403, 451}) ||
        RegExp(r'(forbidden|access denied|sign in|login required|age.restricted|private video)').hasMatch(text)) {
      return 'mediaAccessDenied';
    }
    if (_hasHttpStatus(text, const {429}) ||
        RegExp(r'(too many requests|rate.limit|throttl)').hasMatch(text)) {
      return 'mediaRateLimited';
    }
    if (RegExp(r'(unsupported url|no suitable extractor|unsupported site)').hasMatch(text)) {
      return 'mediaUnsupported';
    }
    if (RegExp(r'(requested format is not available|format not available|no video formats|ffmpeg.*not found|merg)').hasMatch(text)) {
      return 'mediaFormatError';
    }
    if (_hasHttpStatus(text, const {408, 425, 500, 502, 503, 504}) ||
        RegExp(r'(timed out|timeout|network is unreachable|connection reset|connection refused|temporary failure|network error|ssl|certificate)').hasMatch(text)) {
      return 'mediaNetworkError';
    }
    if (RegExp(r'(unable to extract|signature extraction|nsig|challenge|extractor error|player response)').hasMatch(text)) {
      return 'mediaExtractorOutdated';
    }
    return 'mediaUnknownError';
  }
}
