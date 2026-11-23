import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('malformed leading retry hints cannot hide a longer delay', () {
    for (final hint in ['unknown, 600', '-1, 600', '+600', '-600',
      'unknown, Tue, 03 Nov 2026 12:05:00 GMT']) {
      for (final status in [429, 503]) {
        expect(
          TransferPolicy.retryDelayForFailure(
            'HTTP Error $status\nRetry-After: $hint', 1),
          isNull,
          reason: hint,
        );
      }
    }
  });

  test('ordinary unknown hints and unrelated statuses retain fallback', () {
    expect(TransferPolicy.retryDelayForFailure(
      'HTTP Error 429\nRetry-After: unknown', 1),
      const Duration(seconds: 10));
    expect(TransferPolicy.retryDelayForFailure(
      'HTTP Error 500\nRetry-After: unknown, 600', 2),
      const Duration(seconds: 30));
    expect(TransferPolicy.retryDelayForFailure(
      'HTTP Error 503\nRetry-After: 5, 600', 1),
      const Duration(seconds: 600));
  });
}
