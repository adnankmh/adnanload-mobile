import 'package:adnanload_mobile/core/batch_csv_import.dart';
import 'package:adnanload_mobile/core/batch_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> links(String csv) =>
      BatchLinks.parse(BatchCsvImport.extractUrls(csv));

  test('imports semicolon-delimited CSV with download URL priority', () {
    const csv = 'Source URL;Download URL;Title\r\n'
        'https://example.org/page;https://cdn.example.org/a.zip;A\r\n'
        'https://example.org/other;https://cdn.example.org/b.pdf;B\r\n';
    expect(links(csv), [
      'https://cdn.example.org/a.zip',
      'https://cdn.example.org/b.pdf',
    ]);
  });

  test('supports Arabic semicolon headings and quoted separators', () {
    const csv = 'الاسم;رابط التنزيل;ملاحظة\n'
        'تقرير;"https://cdn.example.org/file.zip?sig=one;two";"أ;ب"\n';
    expect(links(csv), [
      'https://cdn.example.org/file.zip?sig=one;two',
    ]);
  });

  test('infers headerless title followed by URL in semicolon CSV', () {
    const csv = 'First;https://example.org/first.zip\n'
        'Second;https://example.org/second.pdf\n';
    expect(links(csv), [
      'https://example.org/first.zip',
      'https://example.org/second.pdf',
    ]);
  });

  test('quoted semicolon in header does not obscure download column', () {
    const csv = '"Title; extra";Download Link\n'
        '"Report; November";https://example.org/report.pdf\n';
    expect(links(csv), ['https://example.org/report.pdf']);
  });

  test('comma CSV retains semicolons inside signed URL parameters', () {
    const csv = 'URL,Title\n'
        '"https://cdn.example.org/file.bin?signature=one;two",Example\n';
    expect(links(csv), [
      'https://cdn.example.org/file.bin?signature=one;two',
    ]);
  });

  test('single signed URL with semicolon is not a CSV delimiter', () {
    const csv = 'https://cdn.example.org/file.bin?signature=one;two\n';
    expect(links(csv), [
      'https://cdn.example.org/file.bin?signature=one;two',
    ]);
  });

  test('malformed quotes are rejected for semicolon CSV too', () {
    const csv = 'URL;Title\n'
        '"https://example.org/a.zip"garbage;A\n';
    expect(() => BatchCsvImport.extractUrls(csv), throwsFormatException);
  });
}
