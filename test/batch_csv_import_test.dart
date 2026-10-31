import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/batch_csv_import.dart';
import 'package:adnanload_mobile/core/batch_links.dart';
import 'package:adnanload_mobile/core/batch_text_import.dart';

void main() {
  test('reads a named URL column and preserves commas inside quoted URLs', () {
    final csv = 'Title,Download URL,Notes\r\n'
        '"Report, October","https://example.org/report.pdf?part=1,2",ok\r\n'
        '"Second","https://example.org/b.zip",ok\r\n';
    expect(BatchLinks.parse(BatchCsvImport.extractUrls(csv)), [
      'https://example.org/report.pdf?part=1,2',
      'https://example.org/b.zip',
    ]);
  });

  test('supports headerless CSV and quoted multiline labels', () {
    const csv = 'https://example.org/a.zip,"First\nfile"\n'
        'https://example.org/b.pdf,Second\n';
    expect(BatchLinks.parse(BatchCsvImport.extractUrls(csv)), [
      'https://example.org/a.zip',
      'https://example.org/b.pdf',
    ]);
  });

  test('filters unsafe and duplicate URLs through existing batch policy', () {
    const csv = 'Name,URL\n'
        'Local,http://127.1/admin\n'
        'One,https://example.org/a.zip\n'
        'Duplicate,https://example.org/a.zip\n'
        'Existing,https://example.org/b.zip\n';
    expect(BatchLinks.parse(BatchCsvImport.extractUrls(csv),
      existing: {'https://example.org/b.zip'}), [
      'https://example.org/a.zip',
    ]);
  });

  test('rejects malformed quoting and empty CSV', () {
    expect(() => BatchCsvImport.extractUrls(''), throwsFormatException);
    expect(() => BatchCsvImport.extractUrls('URL\n"broken'),
        throwsFormatException);
    expect(() => BatchCsvImport.extractUrls('URL\nabc"def'),
        throwsFormatException);
  });

  test('detects second-column URLs in headerless CSV', () {
    const csv = 'First,https://example.org/a.zip\n'
        'Second,https://example.org/b.pdf\n';
    expect(BatchLinks.parse(BatchCsvImport.extractUrls(csv)), [
      'https://example.org/a.zip',
      'https://example.org/b.pdf',
    ]);
  });

  test('detects unknown URL heading and skips the heading row', () {
    const csv = 'Description,Download address,Notes\n'
        'One,https://example.org/one.zip,first\n'
        'Two,https://example.org/two.zip,second\n';
    expect(BatchLinks.parse(BatchCsvImport.extractUrls(csv)), [
      'https://example.org/one.zip',
      'https://example.org/two.zip',
    ]);
  });

  test('keeps first URL column on ties and applies URL safety checks', () {
    const csv = 'http://127.1/admin,https://example.org/alternate\n'
        'https://example.org/safe.zip,https://example.org/other.zip\n';
    expect(BatchLinks.parse(BatchCsvImport.extractUrls(csv)), [
      'https://example.org/safe.zip',
    ]);
  });

  test('accepts UTF-8 BOM and Arabic URL column header', () {
    final bytes = <int>[0xEF, 0xBB, 0xBF,
      ...utf8.encode('العنوان,الرابط\nملف,https://example.org/a.pdf\n')];
    final decoded = BatchTextImport.decode(bytes);
    expect(BatchLinks.parse(BatchCsvImport.extractUrls(decoded)),
        ['https://example.org/a.pdf']);
  });
}
