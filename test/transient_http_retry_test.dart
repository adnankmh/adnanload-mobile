import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/transfer_policy.dart';

void main() {
  test('recognizes native and extractor transient HTTP formats', () {
    for (final reason in ['HTTP Error 429: Too Many Requests', 'HTTP 503',
      'HTTP status 502', 'status code: 504', 'HTTP status code = 408',
      'HTTP Error 500: Internal Server Error', 'Network is unreachable']) {
      expect(TransferPolicy.shouldRetry(reason, 0), isTrue, reason: reason);
      expect(TransferPolicy.shouldRetry(reason, 3), isFalse);
      expect(TransferPolicy.shouldRetry(reason, 0, enabled: false), isFalse);
    }
  });

  test('permanent failures override embedded transient network text', () {
    for (final reason in ['HTTP Error 403: connection reset',
      'HTTP 401: timeout', 'status code: 404; SocketException',
      'DRM protected content; timeout', 'login required: connection reset',
      'No space left on device: temporary failure', 'Unsupported URL: timeout']) {
      expect(TransferPolicy.shouldRetry(reason, 0), isFalse, reason: reason);
    }
    expect(TransferPolicy.shouldRetry('https://example.org/path/503', 0), isFalse);
    expect(TransferPolicy.shouldRetry('timeout', -1), isFalse);
  });
}
