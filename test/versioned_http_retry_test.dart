import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('versioned HTTP status lines classify transient server failures', () {
    for (final message in [
      'HTTP/1.1 503 Service Unavailable',
      'HTTP/2 429',
      'HTTP/2.0 502 Bad Gateway',
      'HTTP/3 408 Request Timeout',
    ]) {
      expect(TransferPolicy.networkTransient(message), isTrue, reason: message);
    }
    expect(TransferPolicy.shouldRetry('HTTP/2 503', 2), isTrue);
    expect(TransferPolicy.shouldRetry('HTTP/2 503', 3), isFalse);
  });

  test('permanent HTTP responses cannot be retried due to socket noise', () {
    for (final message in [
      'HTTP/1.1 403 Forbidden: connection reset',
      'HTTP/2 416 Range Not Satisfiable: connection reset',
      'HTTP/3 412 Precondition Failed: timed out',
      'HTTP/2 404 Not Found: connection closed',
    ]) {
      expect(TransferPolicy.networkTransient(message), isFalse, reason: message);
      expect(TransferPolicy.shouldRetry(message, 0), isFalse, reason: message);
    }
    expect(TransferPolicy.networkTransient('HTTP/2 200 OK'), isFalse);
  });

  test('stale partial and checksum mismatches are not transient', () {
    for (final message in [
      'Content-Range mismatch after connection reset',
      'content-range invalid: timeout',
      'ETag mismatch after timed out',
      'checksum mismatch: connection closed',
      'hash mismatch: connection refused',
    ]) {
      expect(TransferPolicy.networkTransient(message), isFalse, reason: message);
      expect(TransferPolicy.shouldRetry(message, 0), isFalse, reason: message);
    }
  });

  test('ordinary network interruptions remain retryable', () {
    expect(TransferPolicy.networkTransient('SocketException: connection reset'), isTrue);
    expect(TransferPolicy.networkTransient('HTTP Error 429'), isTrue);
    expect(TransferPolicy.networkTransient('status code: 503'), isTrue);
  });
}
