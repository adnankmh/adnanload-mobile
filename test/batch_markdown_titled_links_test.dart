import 'package:adnanload_mobile/core/batch_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Markdown double-quoted titles import only the destination', () {
    const url = 'https://example.org/releases/app.zip';
    expect(
      BatchLinks.parse('[download]($url "Version 2.3")'),
      [url],
    );
  });

  test('single-quoted titles support angle-wrapped signed URLs', () {
    const url = 'https://example.org/file(2).zip?token=a,b;c';
    expect(
      BatchLinks.parse("[archive](<$url> 'Release archive')"),
      [url],
    );
  });

  test('Markdown image titles share fragment-aware deduplication', () {
    const url = 'https://example.org/cover.png';
    expect(
      BatchLinks.parse(
        "![cover]($url#thumbnail 'Cover image')\n$url",
      ),
      [url],
    );
  });

  test('URLs mentioned in Markdown titles are not enqueued', () {
    const url = 'https://example.org/file.zip';
    expect(
      BatchLinks.parse(
        '[download]($url "https://example.org/not-a-download.zip")',
      ),
      [url],
    );
  });

  test('titled Markdown still rejects private and credentialed URLs', () {
    expect(
      BatchLinks.parse(
        '[private](http://127.0.0.1/admin "Local") '
        "[credentials](https://user:pass@example.org/a.zip 'Unsafe') "
        '[public](https://example.org/safe.zip "Safe")',
      ),
      ['https://example.org/safe.zip'],
    );
  });

  test('rejected titled links never enqueue URLs from metadata', () {
    const safe = 'https://example.org/real.zip';
    expect(
      BatchLinks.parse(
        '[https://example.org/label.zip](http://127.0.0.1/admin '
        '"https://example.org/title.zip") '
        "[private](https://user:pass@example.org/a.zip "
        "'https://example.org/other.zip') "
        '$safe',
      ),
      [safe],
    );
  });

  test('signed punctuation survives a quoted Markdown title', () {
    const url = 'https://example.org/file.zip?token=a,;b%29';
    expect(
      BatchLinks.parse('[download]($url "Signed file")'),
      [url],
    );
  });

  test('balanced destinations with titles preserve signed URL bytes', () {
    const url = 'https://example.org/file(2).zip?token=(a,b);c';
    expect(
      BatchLinks.parse('[download]($url "https://example.org/metadata.zip")'),
      [url],
    );
    expect(BatchLinks.parse("![image]($url 'Archive')"), [url]);
  });

  test('rejected balanced titled links hide metadata URLs', () {
    const safe = 'https://example.org/real.zip';
    expect(
      BatchLinks.parse(
        '[https://example.org/label.zip](http://127.0.0.1/a(2).zip '
        '"https://example.org/title.zip") $safe',
      ),
      [safe],
    );
  });
}
