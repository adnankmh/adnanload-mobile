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

  test('rejects unexpected text after a closing quoted URL', () {
    for (final csv in [
      'URL\n"https://example.org/a.zip"garbage\n',
      'URL\n"https://example.org/a.zip""extra"tail\n',
      'URL\n"https://example.org/a.zip" "other"\n',
    ]) {
      expect(() => BatchCsvImport.extractUrls(csv), throwsFormatException,
          reason: csv);
    }
  });

  test('allows harmless whitespace after a closing quote', () {
    const csv = 'URL,Name\r\n'
        '"https://example.org/a.zip" \t,First\r\n'
        '"https://example.org/b.pdf"\t,Second\r\n';
    expect(BatchLinks.parse(BatchCsvImport.extractUrls(csv)), [
      'https://example.org/a.zip',
      'https://example.org/b.pdf',
    ]);
  });

  test('retains escaped quotes in a non-URL CSV field', () {
    const csv = 'Name,URL\n'
        '"October ""final""", "https://example.org/a.zip"\n';
    // Quoted fields must start at the beginning of the field, so a space
    // before a quote is malformed rather than silently reinterpreted.
    expect(() => BatchCsvImport.extractUrls(csv), throwsFormatException);
    const valid = 'Name,URL\n'
        '"October ""final""","https://example.org/a.zip"\n';
    expect(BatchLinks.parse(BatchCsvImport.extractUrls(valid)),
        ['https://example.org/a.zip']);
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


  test('prefers Download Link over Source URL when both are present', () {
    const csv = 'Source URL,Download Link,Title\n'
        'https://example.org/page/1,https://cdn.example.org/one.zip,One\n'
        'https://example.org/page/2,https://cdn.example.org/two.pdf,Two\n';
    expect(BatchLinks.parse(BatchCsvImport.extractUrls(csv)), [
      'https://cdn.example.org/one.zip',
      'https://cdn.example.org/two.pdf',
    ]);
  });

  test('prefers Arabic download header over a generic URL column', () {
    const csv = 'URL,رابط التنزيل\n'
        'https://example.org/watch/1,https://cdn.example.org/video.mp4\n';
    expect(BatchLinks.parse(BatchCsvImport.extractUrls(csv)), [
      'https://cdn.example.org/video.mp4',
    ]);
  });

  test('recognizes File Link and keeps source-only CSV compatibility', () {
    const fileCsv = 'Source URL,File Link\n'
        'https://example.org/page,https://cdn.example.org/file.zip\n';
    expect(BatchLinks.parse(BatchCsvImport.extractUrls(fileCsv)), [
      'https://cdn.example.org/file.zip',
    ]);
    const sourceCsv = 'Name,Source URL\n'
        'One,https://example.org/only-source.zip\n';
    expect(BatchLinks.parse(BatchCsvImport.extractUrls(sourceCsv)), [
      'https://example.org/only-source.zip',
    ]);
  });

  test('explicit download URL wins over generic URL without changing query', () {
    const csv = 'URL,Download URL\n'
        'https://example.org/page,'
        '"https://cdn.example.org/file.zip?signature=a,b;"\n';
    expect(BatchLinks.parse(BatchCsvImport.extractUrls(csv)), [
      'https://cdn.example.org/file.zip?signature=a,b;',
    ]);
  });
}
