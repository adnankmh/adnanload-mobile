import 'package:adnanload_mobile/core/media_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DRM stays protected even when an extractor also reports HTTP 403', () {
    expect(
      MediaFailure.classify('DRM protected content; HTTP Error 403 Forbidden'),
      'mediaProtected',
    );
    expect(
      MediaFailure.classify('Widevine: sign in to confirm you are not a bot'),
      'mediaProtected',
    );
  });

  test('disk exhaustion takes priority over an incidental network timeout', () {
    expect(
      MediaFailure.classify('Connection timed out; no space left on device'),
      'mediaStorageFull',
    );
    expect(MediaFailure.classify('ENOSPC; HTTP Error 503'), 'mediaStorageFull');
  });

  test('HTTP rate limits are recognized across extractor and protocol formats', () {
    for (final error in <String>[
      'HTTP Error 429: Too Many Requests',
      'HTTP/2 429',
      'HTTP/3 429',
      'status code: 429',
      'HTTP status code 429',
    ]) {
      expect(MediaFailure.classify(error), 'mediaRateLimited', reason: error);
    }
  });

  test('temporary HTTP server failures are classified as network errors', () {
    for (final error in <String>[
      'HTTP Error 503: Service Unavailable',
      'HTTP/2 502 Bad Gateway',
      'status code: 504',
      'HTTP/3 425 Too Early',
      'HTTP/1.1 408 Request Timeout',
      'HTTP Error 500',
    ]) {
      expect(MediaFailure.classify(error), 'mediaNetworkError', reason: error);
    }
  });

  test('authentication and legal restrictions are not transient failures', () {
    for (final error in <String>[
      'HTTP/2 401 Unauthorized',
      'status code: 403',
      'HTTP Error 451 Unavailable For Legal Reasons',
    ]) {
      expect(MediaFailure.classify(error), 'mediaAccessDenied', reason: error);
    }
  });

  test('numbers in signed URLs do not impersonate HTTP status codes', () {
    expect(
      MediaFailure.classify(
        'https://example.org/file.mp4?signature=429&token=503',
      ),
      'mediaUnknownError',
    );
    expect(MediaFailure.classify('clip_429_503.mp4'), 'mediaUnknownError');
  });
}
