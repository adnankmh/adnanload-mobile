import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-retryable HTTP statuses override incidental network errors', () {
    for (final message in [
      'HTTP/1.1 301 Moved Permanently: connection closed',
      'HTTP/2 409 Conflict: timeout',
      'HTTP Error 413: SocketException: connection reset',
      'status code: 422; temporarily unavailable',
      'HTTP/3 431 Request Header Fields Too Large: timed out',
      'HTTP/2 501 Not Implemented: connection refused',
      'HTTP/1.1 505 HTTP Version Not Supported: timeout',
    ]) {
      expect(TransferPolicy.networkTransient(message), isFalse,
          reason: message);
      expect(TransferPolicy.shouldRetry(message, 0), isFalse,
          reason: message);
    }
  });

  test('explicit successful HTTP status is not a retry instruction', () {
    expect(TransferPolicy.networkTransient('HTTP/2 200 OK: timeout'), isFalse);
    expect(TransferPolicy.networkTransient(
        'HTTP/1.1 204 No Content: connection reset'), isFalse);
  });

  test('a fatal HTTP status wins over an earlier transient status', () {
    for (final message in [
      'HTTP/2 503; final HTTP/2 413: connection reset',
      'HTTP Error 429; final status code: 422; timeout',
    ]) {
      expect(TransferPolicy.shouldRetry(message, 0), isFalse,
          reason: message);
    }
  });

  test('bounded retries still cover temporary HTTP and socket failures', () {
    for (final message in [
      'HTTP/3 408 Request Timeout',
      'HTTP/2 425 Too Early',
      'HTTP Error 429 Too Many Requests',
      'HTTP/1.1 500 Internal Server Error',
      'HTTP/2 502 Bad Gateway',
      'HTTP/3 503 Service Unavailable',
      'status code: 504',
      'SocketException: connection reset',
      'network is unreachable',
    ]) {
      expect(TransferPolicy.shouldRetry(message, 0), isTrue,
          reason: message);
      expect(TransferPolicy.shouldRetry(message, 3), isFalse,
          reason: message);
    }
  });
}
