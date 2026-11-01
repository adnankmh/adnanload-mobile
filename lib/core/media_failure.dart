/// Only display predefined user-safe messages. Never show extractor logs,
/// tokens, cookies, or private signed URLs in the downloads UI.
class MediaFailure {
  static String classify(String reason) {
    final text = reason.toLowerCase();
    if (RegExp(r'(sign in to confirm|confirm you.re not a bot|unusual traffic|automated requests|captcha|verify you are human)').hasMatch(text)) {
      return 'mediaVerificationRequired';
    }
    if (RegExp(r'(http error 403|status code 403|forbidden|access denied|sign in|login required|age.restricted|private video)').hasMatch(text)) {
      return 'mediaAccessDenied';
    }
    if (RegExp(r'(http error 429|too many requests|rate.limit|throttl)').hasMatch(text)) {
      return 'mediaRateLimited';
    }
    if (RegExp(r'(drm|protected content|widevine)').hasMatch(text)) {
      return 'mediaProtected';
    }
    if (RegExp(r'(unsupported url|no suitable extractor|unsupported site)').hasMatch(text)) {
      return 'mediaUnsupported';
    }
    if (RegExp(r'(requested format is not available|format not available|no video formats|ffmpeg.*not found|merg)').hasMatch(text)) {
      return 'mediaFormatError';
    }
    if (RegExp(r'(timed out|timeout|network is unreachable|connection reset|connection refused|temporary failure|network error|ssl|certificate)').hasMatch(text)) {
      return 'mediaNetworkError';
    }
    if (RegExp(r'(no space left|disk full|enospc|insufficient storage)').hasMatch(text)) {
      return 'mediaStorageFull';
    }
    if (RegExp(r'(unable to extract|signature extraction|nsig|challenge|extractor error|player response)').hasMatch(text)) {
      return 'mediaExtractorOutdated';
    }
    return 'mediaUnknownError';
  }
}
