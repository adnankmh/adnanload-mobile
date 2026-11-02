import 'dart:io';

import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HTTP 429 and 503 honor server Retry-After seconds', () {
    expect(TransferPolicy.retryDelayForFailure(
      'HTTP Error 429: Too Many Requests\nRetry-After: 120', 1),
      const Duration(seconds: 120));
    expect(TransferPolicy.retryDelayForFailure(
      'HTTP/2 503 Service Unavailable; Retry-After: 45', 2),
      const Duration(seconds: 45));
    expect(TransferPolicy.retryDelayForFailure(
      'status code: 429\nRetry-After: 5', 3),
      const Duration(seconds: 90));
  });

  test('HTTP-date Retry-After uses the server deadline', () {
    final now = DateTime.utc(2026, 11, 2, 12);
    final deadline = HttpDate.format(now.add(const Duration(minutes: 7)));
    expect(TransferPolicy.retryDelayForFailure(
      'HTTP Error 429\nRetry-After: $deadline', 1, now: now),
      const Duration(minutes: 7));
    final expired = HttpDate.format(now.subtract(const Duration(minutes: 1)));
    expect(TransferPolicy.retryDelayForFailure(
      'HTTP Error 503\nRetry-After: $expired', 1, now: now),
      const Duration(seconds: 10));
  });

  test('unrelated errors and missing hints retain exponential retry', () {
    expect(TransferPolicy.retryDelayForFailure(
      'SocketException: connection reset; Retry-After: 999', 1),
      const Duration(seconds: 10));
    expect(TransferPolicy.retryDelayForFailure(
      'HTTP Error 500\nRetry-After: 300', 2),
      const Duration(seconds: 30));
    expect(TransferPolicy.retryDelayForFailure(
      'HTTP Error 429', 2), const Duration(seconds: 30));
    expect(TransferPolicy.retryDelayForFailure(
      'HTTP Error 429\nRetry-After: nonsense', 1),
      const Duration(seconds: 10));
  });

  test('excessive backoff prevents premature automatic retries', () {
    expect(TransferPolicy.retryDelayForFailure(
      'HTTP Error 429\nRetry-After: 2592001', 1), isNull);
    expect(TransferPolicy.retryDelayForFailure(
      'HTTP Error 503\nRetry-After: 9999999999999999999999', 1),
      isNull);
    final now = DateTime.utc(2026, 11, 2, 12);
    final farFuture = HttpDate.format(now.add(const Duration(days: 40)));
    expect(TransferPolicy.retryDelayForFailure(
      'HTTP/3 429\nRetry-After: $farFuture', 1, now: now), isNull);
  });

  test('retry eligibility remains bounded by existing HTTP policy', () {
    expect(TransferPolicy.shouldRetry('HTTP Error 429', 0), isTrue);
    expect(TransferPolicy.shouldRetry('HTTP Error 503', 2), isTrue);
    expect(TransferPolicy.shouldRetry('HTTP Error 429', 3), isFalse);
    expect(TransferPolicy.shouldRetry('HTTP Error 403', 0), isFalse);
  });
}
