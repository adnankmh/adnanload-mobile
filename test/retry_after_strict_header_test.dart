import 'dart:io';

import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HTTP-date with extra retry hints cannot shorten server backoff', () {
    final now = DateTime.utc(2026, 11, 3, 12);
    final date = HttpDate.format(now.add(const Duration(seconds: 30)));
    for (final header in [
      '$date, 600',
      '$date, ',
      '$date; extra',
      '${date}garbage',
    ]) {
      expect(
        TransferPolicy.retryDelayForFailure(
          'HTTP Error 429\\nRetry-After: $header', 1, now: now),
        isNull,
        reason: header,
      );
    }
  });

  test('numeric Retry-After accepts no unparsed trailing text', () {
    for (final header in [
      '600 seconds',
      '120; note',
      '120 240',
      '5, 60; note',
      '5, Tue, 03 Nov 2026 12:05:00 GMT',
    ]) {
      expect(
        TransferPolicy.retryDelayForFailure(
          'HTTP/2 503\\nRetry-After: $header', 1),
        isNull,
        reason: header,
      );
    }
  });

  test('strict parsing preserves valid numbers, lists and HTTP-dates', () {
    final now = DateTime.utc(2026, 11, 3, 12);
    final date = HttpDate.format(now.add(const Duration(minutes: 5)));
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP Error 429\\nRetry-After: 120', 1),
      const Duration(seconds: 120),
    );
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP Error 503\\nRetry-After: 5, 180, 60', 2),
      const Duration(seconds: 180),
    );
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP Error 429\\nRetry-After: $date', 1, now: now),
      const Duration(minutes: 5),
    );
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP Error 429\\nRetry-After: 5', 3),
      const Duration(seconds: 90),
    );
  });

  test('unknown hints and non-rate-limit failures keep retry policy', () {
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP Error 429\\nRetry-After: unknown', 1),
      const Duration(seconds: 10),
    );
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP Error 500\\nRetry-After: 600 seconds', 2),
      const Duration(seconds: 30),
    );
  });
}
