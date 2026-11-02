import 'dart:io';

import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('combined Retry-After delays use the longest server hint', () {
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP Error 429\nRetry-After: 5, 180, 60', 1),
      const Duration(seconds: 180),
    );
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP/2 503\nRetry-After: 120, 5', 2),
      const Duration(seconds: 120),
    );
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP Error 429\nRetry-After: 0, 5', 3),
      const Duration(seconds: 90),
    );
  });

  test('oversized or ambiguous combined hints cannot retry prematurely', () {
    for (final header in [
      '5, 2592001',
      '5, 999999999999999999999',
      '5, garbage',
      '5, ',
      '5, -1',
      '5, 120; note',
    ]) {
      expect(
        TransferPolicy.retryDelayForFailure(
          'HTTP Error 429\nRetry-After: $header', 1),
        isNull,
        reason: header,
      );
    }
  });

  test('single-value and HTTP-date backoff remain supported', () {
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP Error 503\nRetry-After: 120', 1),
      const Duration(seconds: 120),
    );
    final now = DateTime.utc(2026, 11, 3, 12);
    final deadline = HttpDate.format(now.add(const Duration(minutes: 5)));
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP Error 429\nRetry-After: $deadline', 1, now: now),
      const Duration(minutes: 5),
    );
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP Error 500\nRetry-After: 5, 180', 1),
      const Duration(seconds: 10),
    );
  });
}
