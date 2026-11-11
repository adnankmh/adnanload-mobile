import 'package:adnanload_mobile/core/batch_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Markdown destination keeps a parenthesized filename', () {
    const url = 'https://example.org/releases/app(2).zip';
    expect(BatchLinks.parse('[download release]($url)'), [url]);
  });

  test('nested parentheses in paths survive Markdown extraction', () {
    const url = 'https://example.org/(archive(v2))/report.pdf';
    expect(BatchLinks.parse('[annual report]($url)'), [url]);
  });

  test('signed query parentheses and punctuation are not truncated', () {
    const url = 'https://example.org/file(1).zip?token=(a,b);c';
    expect(BatchLinks.parse('[signed download]($url)'), [url]);
  });

  test('image Markdown shares fragment deduplication with bare links', () {
    const url = 'https://example.org/cover(1).png';
    expect(
      BatchLinks.parse(
        '![cover image]($url#preview)\\n$url',
      ),
      [url],
    );
  });

  test('malformed and private parenthesized Markdown links stay blocked', () {
    expect(
      BatchLinks.parse(
        '[unfinished](https://example.org/file(1).zip '
        '[private](http://127.0.0.1/secret(2)) '
        '[safe](https://example.org/public(3).zip)',
      ),
      ['https://example.org/public(3).zip'],
    );
  });

  test('balanced Markdown links retain the 100-link batch cap', () {
    final text = List.generate(
      103,
      (index) => '[file $index](https://example.org/file($index).zip)',
    ).join('\\n');
    final result = BatchLinks.parse(text);
    expect(result.length, BatchLinks.maxLinks);
    expect(result.first, 'https://example.org/file(0).zip');
    expect(result.last, 'https://example.org/file(99).zip');
  });
}
