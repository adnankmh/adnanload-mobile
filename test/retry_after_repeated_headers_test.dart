import 'dart:io';

import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repeated numeric Retry-After lines honor the longest delay', () {
    const failure = 'HTTP Error 429\nRetry-After: 5\nRetry-After: 180';
    expect(
      TransferPolicy.retryDelayForFailure(failure, 1),
      const Duration(seconds: 180),
    );
    // A combined numeric header and another line must also be aggregated.
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP/2 503\nRetry-After: 5, 20\nRetry-After: 90', 2),
      const Duration(seconds: 90),
    );
  });

  test('repeated HTTP-date and numeric hints honor the later deadline', () {
    final now = DateTime.utc(2026, 11, 3, 12);
    final later = HttpDate.format(now.add(const Duration(minutes: 5)));
    for (final failure in [
      'HTTP Error 429\nRetry-After: 60\nRetry-After: $later',
      'HTTP Error 429\nRetry-After: $later\nRetry-After: 60',
    ]) {
      expect(
        TransferPolicy.retryDelayForFailure(failure, 1, now: now),
        const Duration(minutes: 5),
        reason: failure,
      );
    }
  });

  test('malformed or empty repeated hints require manual retry', () {
    for (final failure in [
      'HTTP Error 429\nRetry-After: 5\nRetry-After: 600 seconds',
      'HTTP/2 503\nRetry-After: 5\nRetry-After: ',
      'HTTP Error 429\nRetry-After: 5\nRetry-After: nonsense',
      'HTTP Error 429\nRetry-After: 5\nRetry-After: 2592001',
    ]) {
      expect(
        TransferPolicy.retryDelayForFailure(failure, 1),
        isNull,
        reason: failure,
      );
    }
  });

  test('an excessive number of repeated headers fails closed', () {
    final failure = [
      'HTTP Error 429',
      for (var i = 0; i < 17; i++) 'Retry-After: 5',
    ].join('\n');
    expect(TransferPolicy.retryDelayForFailure(failure, 1), isNull);
  });

  test('ordinary retries and single valid hints retain prior behavior', () {
    expect(
      TransferPolicy.retryDelayForFailure('HTTP Error 429', 1),
      const Duration(seconds: 10),
    );
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP Error 429\nRetry-After: 2', 1),
      const Duration(seconds: 10),
    );
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP Error 429\nRetry-After: 40', 1),
      const Duration(seconds: 40),
    );
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP Error 429\nRetry-After: nonsense', 1),
      const Duration(seconds: 10),
    );
  });
}
