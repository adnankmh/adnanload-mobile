import 'package:adnanload_mobile/core/batch_links.dart';
import 'package:adnanload_mobile/core/url_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects invisible direction and format controls in URLs', () {
    for (final url in <String>[
      'https://example.org/file\u202Egpj.exe',
      'https://example.org/download?token=abc\u2066def',
      'https://exa\u200Bmple.org/file.zip',
      'https://example.org/file\u00AD.zip',
      'https://example.org/file\u061C.zip',
      'https://example.org/file\uFEFF.zip',
      'https://example.org/file\u0000.zip',
      'https://example.org/file\r\nHost: localhost',
    ]) {
      expect(UrlGuard.validate(url), isNull, reason: url);
    }
  });

  test('ordinary public URLs and percent-encoded data remain supported', () {
    for (final url in <String>[
      'https://example.org/normal.zip?signature=a,b;',
      'https://example.org/%E2%80%AEfile.zip',
      'https://example.org/%D9%85%D9%84%D9%81.pdf',
      '  https://example.org/file.zip\n',
    ]) {
      expect(UrlGuard.validate(url), isNotNull, reason: url);
    }
  });

  test('batch import skips disguised links without dropping valid entries', () {
    expect(BatchLinks.parse(
      'https://example.org/file\u202Egpj.exe\n'
      'https://example.org/safe.zip?signature=abc,;\n'
      'https://example.org/file\u2069.pdf',
    ), <String>['https://example.org/safe.zip?signature=abc,;']);
  });
}
