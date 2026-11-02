import 'package:adnanload_mobile/core/url_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removes invisible controls that can disguise file extensions', () {
    final examples = <String, String>{
      'report\u061C.pdf': 'report.pdf', // Arabic letter mark
      'photo\u2063.exe': 'photo.exe', // invisible separator
      'archive\uFEFF.zip': 'archive.zip', // byte order mark
      'draft\u2028next.pdf': 'draftnext.pdf', // line separator
      'invoice\u00AD.exe': 'invoice.exe', // soft hyphen
      'photo\u200B.jpg': 'photo.jpg', // zero-width space
    };
    for (final entry in examples.entries) {
      expect(UrlGuard.safeName(entry.key), entry.value,
          reason: 'unexpected invisible character in output');
    }
  });

  test('preserves meaningful zero-width joiners in emoji', () {
    expect(UrlGuard.safeName('👩‍💻.png'), '👩‍💻.png');
  });

  test('Windows reserved device names remain blocked before padded dots', () {
    for (final name in ['CON .txt', 'NUL  .pdf', 'LPT9 .zip']) {
      expect(UrlGuard.safeName(name).startsWith('_'), isTrue,
          reason: name);
    }
    expect(UrlGuard.safeName('normal .txt'), 'normal .txt');
  });

  test('URL extraction and collision policy inherit filename protections', () {
    expect(
      UrlGuard.nameFromUrl('https://example.org/invoice%E2%80%AEpdf.exe'),
      'invoicepdf.exe',
    );
    expect(
      UrlGuard.uniqueName('invoice\u061C.pdf', {'invoice.pdf'}),
      'invoice_1.pdf',
    );
  });
}
