import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/media_failure.dart';

void main() {
  test('media failures classify without exposing secret URLs', () {
    expect(MediaFailure.classify('HTTP Error 403: Forbidden https://example.com/?token=SECRET'),
      'mediaAccessDenied');
    expect(MediaFailure.classify('HTTP Error 429'), 'mediaRateLimited');
    expect(MediaFailure.classify('DRM protected content'), 'mediaProtected');
    expect(MediaFailure.classify('Requested format is not available'), 'mediaFormatError');
    expect(MediaFailure.classify('Connection timed out'), 'mediaNetworkError');
    expect(MediaFailure.classify('No space left on device'), 'mediaStorageFull');
    expect(MediaFailure.classify('Unable to extract signature'), 'mediaExtractorOutdated');
    expect(MediaFailure.classify('Unsupported URL'), 'mediaUnsupported');
    expect(MediaFailure.classify('https://example.com/?token=SECRET'), 'mediaUnknownError');
  });
}
