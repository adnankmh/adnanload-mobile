import 'package:adnanload_mobile/core/batch_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Markdown labels with spaces import only their destination URLs', () {
    expect(
      BatchLinks.parse(
        'Open [annual report (PDF)](https://example.org/report.pdf) '
        'and [the archive](https://example.org/archive.zip).',
      ),
      [
        'https://example.org/report.pdf',
        'https://example.org/archive.zip',
      ],
    );
  });

  test('Markdown image links and plain URLs use the same deduplication', () {
    expect(
      BatchLinks.parse(
        '![cover image](https://example.org/cover.png#preview)\n'
        'https://example.org/cover.png\n'
        '[another image](https://example.org/other.png)',
        existing: {'https://example.org/other.png#old'},
      ),
      ['https://example.org/cover.png'],
    );
  });

  test('signed query punctuation survives Markdown extraction', () {
    const signed = 'https://example.org/file.zip?token=a,;b%29';
    expect(
      BatchLinks.parse('[download here]($signed)'),
      [signed],
    );
  });

  test('unsafe and malformed Markdown links never enter the queue', () {
    expect(
      BatchLinks.parse(
        '[private](http://127.0.0.1/admin) '
        '[local](file:///etc/passwd) '
        '[credentials](https://user:pass@example.org/secret.zip) '
        '[unfinished](https://example.org/missing.zip '
        '[safe](https://example.org/ok.zip)',
      ),
      ['https://example.org/ok.zip'],
    );
  });

  test('bare signed URLs with parentheses remain untouched', () {
    const url = 'https://example.org/archive.zip?token=(abc),;';
    expect(BatchLinks.parse(url), [url]);
  });
}
