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

  test('rejects C1 and legacy invisible separators in unescaped links', () {
    for (final url in <String>[
      'https://example.org/file\u0085.zip',
      'https://example.org/file\u009F.zip',
      'https://example.org/file\u180E.zip',
      'https://exa\u180Emple.org/archive.zip',
      'https://example.org/file.zip?token=a\u0080b',
    ]) {
      expect(UrlGuard.validate(url), isNull, reason: url);
    }
  });

  test('retains escaped control bytes without changing signed query values', () {
    for (final url in <String>[
      'https://example.org/file%C2%85.zip',
      'https://example.org/file%E1%A0%8E.zip',
      'https://example.org/archive.zip?token=a%2Cb%3B',
    ]) {
      expect(UrlGuard.validate(url)?.toString(), url, reason: url);
    }
  });
}
