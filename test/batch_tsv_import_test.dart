import 'package:adnanload_mobile/core/batch_csv_import.dart';
import 'package:adnanload_mobile/core/batch_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> links(String input) =>
      BatchLinks.parse(BatchCsvImport.extractUrls(input));

  test('TSV prefers download URL over source URL and preserves signatures', () {
    const input = 'Source URL\tDownload URL\tTitle\n'
        'https://example.org/page\t'
        '"https://cdn.example.org/archive.zip?sig=a,b;c"\t'
        '"Report\tNovember"\n';
    expect(links(input), [
      'https://cdn.example.org/archive.zip?sig=a,b;c',
    ]);
  });

  test('Arabic TSV header selects the download column', () {
    const input = 'الاسم\tرابط التنزيل\tالرابط\n'
        'تقرير\thttps://cdn.example.org/report.pdf\t'
        'https://example.org/page\n';
    expect(links(input), ['https://cdn.example.org/report.pdf']);
  });

  test('headerless TSV detects URL in second column', () {
    const input = '"Report, October"\thttps://example.org/one.zip\n'
        'Second\thttps://example.org/two.pdf\n';
    expect(links(input), [
      'https://example.org/one.zip',
      'https://example.org/two.pdf',
    ]);
  });

  test('tabs and punctuation in descriptive TSV heading do not change dialect', () {
    const input = 'Title, description; notes\tDownload Link\tSource URL\n'
        'Report\thttps://cdn.example.org/a.zip\thttps://example.org/page\n';
    expect(links(input), ['https://cdn.example.org/a.zip']);
  });

  test('comma and semicolon CSV keep their recognized URL columns', () {
    const comma = 'Title\tNotes,Download URL\n'
        'Report,https://example.org/a.zip\n';
    const semicolon = 'Title\tNotes;Download URL\n'
        'Report;https://example.org/b.zip\n';
    expect(links(comma), ['https://example.org/a.zip']);
    expect(links(semicolon), ['https://example.org/b.zip']);
  });

  test('malformed quoted TSV fields fail closed', () {
    const input = 'URL\tTitle\n'
        '"https://example.org/a.zip"junk\tReport\n';
    expect(() => BatchCsvImport.extractUrls(input), throwsFormatException);
  });

  test('TSV still rejects local and duplicate download links', () {
    const input = 'URL\tName\n'
        'http://127.0.0.1/private\tLocal\n'
        'https://example.org/safe.zip\tFirst\n'
        'https://example.org/safe.zip\tDuplicate\n';
    expect(links(input), ['https://example.org/safe.zip']);
  });
}
