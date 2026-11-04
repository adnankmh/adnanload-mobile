import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('URL query parameters cannot turn socket errors into HTTP statuses', () {
    const failure =
        'SocketException: connection reset while fetching '
        'https://cdn.example.org/file.bin?status=404&http=503';
    expect(TransferPolicy.networkTransient(failure), isTrue);
    expect(TransferPolicy.shouldRetry(failure, 0), isTrue);
    expect(TransferPolicy.retryDelayForFailure(failure, 1),
        const Duration(seconds: 10));
  });

  test('URL query parameters cannot invent a rate-limit response', () {
    const failure =
        'SocketException: connection reset '
        'https://cdn.example.org/file?status=503&http=429\\n'
        'Retry-After: 600';
    expect(TransferPolicy.networkTransient(failure), isTrue);
    expect(TransferPolicy.retryDelayForFailure(failure, 1),
        const Duration(seconds: 10));
  });

  test('real HTTP statuses take precedence over URL query parameters', () {
    const throttled =
        'HTTP Error 429 https://cdn.example.org/file?status=404\\n'
        'Retry-After: 180';
    expect(TransferPolicy.networkTransient(throttled), isTrue);
    expect(TransferPolicy.retryDelayForFailure(throttled, 1),
        const Duration(seconds: 180));

    const forbidden =
        'HTTP/2 403 Forbidden: connection reset '
        'https://cdn.example.org/file?status=503';
    expect(TransferPolicy.networkTransient(forbidden), isFalse);
    expect(TransferPolicy.shouldRetry(forbidden, 0), isFalse);
  });

  test('standalone equals and standard HTTP log formats stay supported', () {
    for (final message in [
      'status=503',
      'HTTP=429',
      'HTTP/2 503',
      'status code: 504',
      'error:HTTP Error 429',
    ]) {
      expect(TransferPolicy.networkTransient(message), isTrue,
          reason: message);
    }
    expect(TransferPolicy.retryDelayForFailure(
        'status=503\\nRetry-After: 120', 1),
        const Duration(seconds: 120));
  });
}
