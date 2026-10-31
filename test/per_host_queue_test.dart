import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('limits in-app direct queue to two transfers per host', () {
    final active = <String, int>{};
    const first = 'https://downloads.example.org/one.zip';
    const second = 'https://downloads.example.org/two.zip';
    expect(TransferPolicy.mayStartDirectHost(first, active), isTrue);
    TransferPolicy.countDirectHost(first, active);
    expect(TransferPolicy.mayStartDirectHost(second, active), isTrue);
    TransferPolicy.countDirectHost(second, active);
    expect(TransferPolicy.mayStartDirectHost(
        'https://downloads.example.org/three.zip', active), isFalse);
    expect(TransferPolicy.mayStartDirectHost(
        'https://other.example.org/three.zip', active), isTrue);
  });

  test('normalizes host casing, trailing dots, ports and schemes', () {
    final active = <String, int>{};
    TransferPolicy.countDirectHost('https://EXAMPLE.org:443/a', active);
    TransferPolicy.countDirectHost('http://example.org./b', active);
    expect(active, {'example.org': 2});
    expect(TransferPolicy.mayStartDirectHost(
        'https://example.org:8443/c', active), isFalse);
  });

  test('subdomains have separate limits', () {
    final active = <String, int>{};
    TransferPolicy.countDirectHost('https://a.example.org/a', active);
    TransferPolicy.countDirectHost('https://a.example.org/b', active);
    expect(TransferPolicy.mayStartDirectHost(
        'https://b.example.org/c', active), isTrue);
  });

  test('invalid URL and unsupported scheme cannot claim queue slots', () {
    final active = <String, int>{};
    for (final url in ['', 'not a url', 'file:///tmp/file',
        'ftp://example.org/a', 'https:///missing-host']) {
      expect(TransferPolicy.mayStartDirectHost(url, active), isFalse,
          reason: url);
      TransferPolicy.countDirectHost(url, active);
    }
    expect(active, isEmpty);
    expect(TransferPolicy.mayStartDirectHost(
        'https://example.org/a', active, maxPerHost: 0), isFalse);
  });

  test('capacity returns after a completed task leaves the active set', () {
    final active = <String, int>{};
    TransferPolicy.countDirectHost('https://example.org/a', active);
    TransferPolicy.countDirectHost('https://example.org/b', active);
    expect(TransferPolicy.mayStartDirectHost(
        'https://example.org/c', active), isFalse);
    active['example.org'] = 1;
    expect(TransferPolicy.mayStartDirectHost(
        'https://example.org/c', active), isTrue);
  });
}
