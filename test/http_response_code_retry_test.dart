import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HTTP response code labels preserve transient and fatal precedence', () {
    expect(TransferPolicy.shouldRetry('HTTP response code: 503', 0), isTrue);
    expect(TransferPolicy.shouldRetry('HTTP response code: 403; timeout', 0),
        isFalse);
    expect(TransferPolicy.shouldRetry(
        'HTTP 503; HTTP response code: 416; connection reset', 0), isFalse);
  });

  test('response code labels honor server backoff without URL false positives', () {
    expect(TransferPolicy.retryDelayForFailure(
        'HTTP response code: 429\nRetry-After: 75', 1),
        const Duration(seconds: 75));
    expect(TransferPolicy.shouldRetry(
        'Download failed https://example.org/file?HTTP=response%20code:503',
        0), isFalse);
  });
}
