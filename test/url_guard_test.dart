import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/url_guard.dart';

void main() {
  test('allows normal HTTPS direct links', () {
    expect(UrlGuard.validate('https://example.com/test.mp4?a=1'), isNotNull);
  });
  test('blocks unsafe or local schemes and destinations', () {
    for (final url in [
      'file:///etc/passwd', 'javascript:alert(1)',
      'http://localhost/a', 'http://127.0.0.1/a',
      'http://192.168.0.1/a', 'http://169.254.1.1/a',
      'https://user:pass@example.com/a',
    ]) {
      expect(UrlGuard.validate(url), isNull, reason:url);
    }
  });
  test('blocks alternate numeric spellings of private hosts', () {
    for (final url in [
      'http://127.1/admin',
      'http://2130706433/admin',
      'http://0x7f000001/admin',
      'http://0177.0.0.1/admin',
      'http://127.0.0.1./admin',
      'http://localhost./admin',
      'http://192.168.1.1./admin',
      'http://10.1/private',
      'http://192.168.001.001/private',
    ]) {
      expect(UrlGuard.validate(url), isNull, reason: url);
    }
  });

  test('continues accepting ordinary public IPs and domain names', () {
    for (final url in [
      'https://example.org/file.zip',
      'https://cdn123.example.org/video.mp4',
      'https://example.org./file.zip',
      'http://8.8.8.8/file.zip',
    ]) {
      expect(UrlGuard.validate(url), isNotNull, reason: url);
    }
  });

  test('suggests original decoded filename', () {
    expect(UrlGuard.nameFromUrl('https://example.com/hello%20world.pdf?token=a'), 'hello world.pdf');
  });
  test('sanitizes path characters', () {
    expect(UrlGuard.safeName('bad/a\\b:*.mp4'), 'bad_a_b__.mp4');
  });
}
