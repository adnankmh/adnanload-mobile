import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/transfer_policy.dart';

void main() {
  test('certificate trust failures never trigger automatic retry', () {
    for (final failure in [
      'HandshakeException: CERTIFICATE_VERIFY_FAILED; SocketException',
      'HTTP 503: certificate has expired',
      'SocketException: self-signed certificate',
      'connection reset: hostname mismatch',
      'CertPathValidatorException: Trust anchor for certification path not found',
    ]) {
      expect(TransferPolicy.shouldRetry(failure, 0), isFalse,
          reason: failure);
    }
  });

  test('ordinary transport failures and URL isolation remain intact', () {
    expect(TransferPolicy.shouldRetry('SocketException: connection reset', 0),
        isTrue);
    expect(TransferPolicy.shouldRetry('HTTP 503', 0), isTrue);
    expect(TransferPolicy.shouldRetry(
        'SocketException: timeout https://example.com/CERTIFICATE_VERIFY_FAILED',
        0), isTrue);
  });
}
