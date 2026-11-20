import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('URL-only transient words cannot manufacture a network retry', () {
    for (final url in <String>[
      'https://cdn.example.org/timeout/file.zip',
      'https://cdn.example.org/socketexception/file.zip',
      'https://cdn.example.org/file?error=connection%20reset&hint=timeout',
      'https://cdn.example.org/temporarily-unavailable/file.zip',
    ]) {
      final failure = 'Download failed for $url';
      expect(TransferPolicy.networkTransient(failure), isFalse, reason: url);
      expect(TransferPolicy.shouldRetry(failure, 0), isFalse, reason: url);
    }
  });

  test('URL-only permanent keywords cannot suppress a real socket retry', () {
    for (final url in <String>[
      'https://cdn.example.org/drm/file.zip',
      'https://cdn.example.org/widevine/file.zip',
      'https://cdn.example.org/login-required/file.zip',
      'https://cdn.example.org/unsupported%20url/file.zip',
    ]) {
      final failure = 'SocketException: connection reset $url';
      expect(TransferPolicy.networkTransient(failure), isTrue, reason: url);
      expect(TransferPolicy.shouldRetry(failure, 0), isTrue, reason: url);
    }
  });

  test('URL query Retry-After is not a real backoff header', () {
    for (final url in <String>[
      'https://cdn.example.org/file?retry-after:600',
      'https://cdn.example.org/retry-after:2592001/file',
      'https://cdn.example.org/file?x=1;Retry-After:3600',
    ]) {
      final failure = 'HTTP Error 429 $url';
      expect(TransferPolicy.retryDelayForFailure(failure, 1),
          const Duration(seconds: 10), reason: url);
    }
  });

  test('real Retry-After outside a URL remains authoritative', () {
    const url = 'https://cdn.example.org/file?retry-after:3600';
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP/2 503 $url\nRetry-After: 75', 1),
      const Duration(seconds: 75),
    );
    expect(
      TransferPolicy.retryDelayForFailure(
        'HTTP Error 429; Retry-After: 45', 1),
      const Duration(seconds: 45),
    );
  });

  test('real permanent HTTP status still overrides URL noise', () {
    const failure = 'HTTP/2 403: timeout '
        'https://cdn.example.org/file?status=503&retry-after:60';
    expect(TransferPolicy.networkTransient(failure), isFalse);
    expect(TransferPolicy.shouldRetry(failure, 0), isFalse);
  });
}
