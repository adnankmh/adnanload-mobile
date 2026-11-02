import 'package:adnanload_mobile/core/batch_csv_import.dart';
import 'package:adnanload_mobile/core/batch_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TXT batch import preserves terminal signed query punctuation', () {
    const comma = 'https://example.org/a.zip?signature=abc,';
    const semicolon = 'https://example.org/b.zip?signature=xyz;';
    expect(BatchLinks.parse('$comma\n$semicolon'), [comma, semicolon]);
  });

  test('quoted CSV URLs keep trailing delimiters inside signed queries', () {
    const csv = 'URL,Label\n'
        '"https://example.org/a.zip?signature=abc,;","archive"\n';
    expect(BatchLinks.parse(BatchCsvImport.extractUrls(csv)), [
      'https://example.org/a.zip?signature=abc,;',
    ]);
  });

  test('signed URL deduplication preserves punctuation and ignores fragments', () {
    const url = 'https://example.org/file.mp4?token=abc,;';
    expect(BatchLinks.parse('$url#one\n$url#two'), [url]);
    expect(BatchLinks.parse(url, existing: {'$url#old'}), isEmpty);
  });

  test('plain prose punctuation and unsafe URLs remain filtered', () {
    expect(BatchLinks.parse(
      'https://example.org/a.zip, '
      'https://example.org/b.pdf; '
      'http://127.0.0.1/admin?token=abc,;',
    ), [
      'https://example.org/a.zip',
      'https://example.org/b.pdf',
    ]);
  });
}
