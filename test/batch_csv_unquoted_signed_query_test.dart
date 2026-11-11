import 'package:adnanload_mobile/core/batch_csv_import.dart';
import 'package:adnanload_mobile/core/batch_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> imported(String input) =>
      BatchLinks.parse(BatchCsvImport.extractUrls(input));

  test('unquoted signed query comma is never interpreted as a CSV column', () {
    const url = 'https://example.org/archive.zip?signature=alpha,beta';
    expect(imported('$url\\n'), [url]);
  });

  test('preserves trailing signed commas across multiple URL-only rows', () {
    const first = 'https://example.org/a.zip?token=abc,';
    const second = 'https://example.org/b.pdf?token=one,two';
    expect(imported('$first\\r\\n$second\\r\\n'), [first, second]);
  });

  test('explicit comma CSV headers and download-column priority still work', () {
    const csv = 'Source URL,Download URL\\n'
        'https://example.org/page,'
        '"https://cdn.example.org/file.zip?signature=a,b"\\n';
    expect(imported(csv), [
      'https://cdn.example.org/file.zip?signature=a,b',
    ]);
  });

  test('unsafe local signed URLs remain blocked by the batch URL guard', () {
    const csv = 'http://127.0.0.1/private?token=a,b\\n'
        'https://example.org/safe.zip?token=x,y\\n';
    expect(imported(csv), ['https://example.org/safe.zip?token=x,y']);
  });
}
