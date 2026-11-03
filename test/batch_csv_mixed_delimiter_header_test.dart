import 'package:adnanload_mobile/core/batch_csv_import.dart';
import 'package:adnanload_mobile/core/batch_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> links(String csv) =>
      BatchLinks.parse(BatchCsvImport.extractUrls(csv));

  test('semicolon download header wins over comma in descriptive header', () {
    const csv = 'Title, description;Download URL;Source URL\n'
        'Report;https://cdn.example.org/report.pdf;https://example.org/page\n';
    expect(links(csv), ['https://cdn.example.org/report.pdf']);
  });

  test('Arabic semicolon header wins over comma in descriptive heading', () {
    const csv = 'الاسم, الوصف;رابط التنزيل;المصدر\r\n'
        'تقرير;https://cdn.example.org/a.zip;https://example.org/page\r\n';
    expect(links(csv), ['https://cdn.example.org/a.zip']);
  });

  test('comma CSV still wins when its description includes a semicolon', () {
    const csv = 'Title; notes,Download URL,Source URL\n'
        'Report,https://cdn.example.org/a.zip,https://example.org/page\n';
    expect(links(csv), ['https://cdn.example.org/a.zip']);
  });

  test('signed URL punctuation survives semicolon header detection', () {
    const csv = 'Title, description;Download URL\n'
        'Report;"https://cdn.example.org/file.bin?signature=one,two;three"\n';
    expect(links(csv), [
      'https://cdn.example.org/file.bin?signature=one,two;three',
    ]);
  });

  test('quoted semicolon in comma CSV metadata retains comma dialect', () {
    const csv = '"Title; extra",Download URL\n'
        '"Report; November",https://cdn.example.org/report.pdf\n';
    expect(links(csv), ['https://cdn.example.org/report.pdf']);
  });
}
