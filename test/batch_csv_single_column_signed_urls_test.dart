import 'package:adnanload_mobile/core/batch_csv_import.dart';
import 'package:adnanload_mobile/core/batch_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> imported(String csv) =>
      BatchLinks.parse(BatchCsvImport.extractUrls(csv));

  test('single-column URL header preserves commas in later signed rows', () {
    const csv = 'URL\r\n'
        'https://example.org/plain.zip\r\n'
        'https://example.org/signed.zip?signature=one,two\r\n'
        'https://example.org/last.pdf?token=abc,\r\n';
    expect(imported(csv), [
      'https://example.org/plain.zip',
      'https://example.org/signed.zip?signature=one,two',
      'https://example.org/last.pdf?token=abc,',
    ]);
  });

  test('Arabic one-column download header preserves signed URL bytes', () {
    const csv = 'رابط التنزيل\n'
        'https://cdn.example.org/report.pdf?sig=alpha,beta\n';
    expect(imported(csv), [
      'https://cdn.example.org/report.pdf?sig=alpha,beta',
    ]);
  });

  test('headerless URL list preserves signed commas after a plain first row', () {
    const csv = 'https://example.org/first.zip\n'
        'https://example.org/second.zip?sig=one,two\n';
    expect(imported(csv), [
      'https://example.org/first.zip',
      'https://example.org/second.zip?sig=one,two',
    ]);
  });

  test('local URLs and duplicates remain blocked in one-column imports', () {
    const csv = 'URL\n'
        'http://127.0.0.1/admin?sig=one,two\n'
        'https://example.org/ok.zip?sig=abc,def\n'
        'https://example.org/ok.zip?sig=abc,def\n';
    expect(imported(csv), ['https://example.org/ok.zip?sig=abc,def']);
  });

  test('explicit two-column CSV keeps normal quoting and column selection', () {
    const csv = 'URL,Title\n'
        '"https://example.org/archive.zip?sig=one,two",Archive\n';
    expect(imported(csv), [
      'https://example.org/archive.zip?sig=one,two',
    ]);
  });

  test('malformed quoted CSV is still rejected, not silently accepted', () {
    const csv = 'URL\n"https://example.org/a.zip"garbage\n';
    expect(() => BatchCsvImport.extractUrls(csv), throwsFormatException);
  });
}
