import 'package:adnanload_mobile/core/batch_links.dart';
import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:adnanload_mobile/core/url_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blocks documentation, benchmark and deprecated relay IPv4 ranges', () {
    for (final address in [
      '192.0.0.0', '192.0.0.1', '192.0.0.8',
      '192.0.0.11', '192.0.0.170', '192.0.0.171', '192.0.0.255',
      '192.0.2.1', '192.0.2.255',
      '192.88.99.1',
      '198.18.0.1', '198.19.255.255',
      '198.51.100.42', '203.0.113.17',
    ]) {
      final url = 'https://$address/archive.zip';
      expect(UrlGuard.validate(url), isNull, reason: url);
      expect(UrlGuard.validate('http://$address./archive.zip'), isNull,
          reason: 'trailing DNS root dot: $address');
    }
  });

  test('special-use addresses never enter batch or per-host queues', () {
    const invalid = 'https://192.0.0.170/file.zip';
    const valid = 'https://8.8.8.8/file.zip';
    expect(BatchLinks.parse('$invalid\n$valid'), [valid]);
    expect(TransferPolicy.directHost(invalid), isNull);
    expect(TransferPolicy.mayStartDirectHost(invalid, {}), isFalse);
    final counts = <String, int>{};
    TransferPolicy.countDirectHost(invalid, counts);
    expect(counts, isEmpty);
  });

  test('ordinary public IPv4 downloads remain accepted', () {
    for (final address in [
      '1.1.1.1', '8.8.8.8', '9.9.9.9', '198.20.0.1',
      // These two protocol-assignment anycast addresses are globally reachable.
      '192.0.0.9', '192.0.0.10',
    ]) {
      final url = 'https://$address/file.zip';
      expect(UrlGuard.validate(url), isNotNull, reason: url);
    }
  });
}
