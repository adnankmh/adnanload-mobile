import 'package:adnanload_mobile/core/batch_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('history URLs with fragments reserve the underlying resource', () {
    expect(
      BatchLinks.parse(
        'https://example.org/archive.zip#new-view',
        existing: {'https://example.org/archive.zip#old-view'},
      ),
      isEmpty,
    );
  });

  test('fragment-only differences in one batch do not queue duplicates', () {
    expect(
      BatchLinks.parse(
        'https://example.org/archive.zip#one\n'
        'https://example.org/archive.zip#two\n'
        'https://example.org/archive.zip',
      ),
      ['https://example.org/archive.zip'],
    );
  });

  test('distinct signed query parameters remain distinct and unchanged', () {
    expect(
      BatchLinks.parse(
        'https://example.org/file.mp4?token=first#player\n'
        'https://example.org/file.mp4?token=second#player',
        existing: {'https://example.org/file.mp4?token=old#player'},
      ),
      [
        'https://example.org/file.mp4?token=first',
        'https://example.org/file.mp4?token=second',
      ],
    );
  });

  test('whitespace in persisted history cannot bypass deduplication', () {
    expect(
      BatchLinks.parse(
        'https://example.org/a.pdf',
        existing: {'  https://example.org/a.pdf#section  '},
      ),
      isEmpty,
    );
  });

  test('unsafe history and new URLs remain rejected by the URL guard', () {
    expect(
      BatchLinks.parse(
        'http://127.0.0.1/private\n'
        'https://example.org/valid.pdf#preview',
        existing: {
          'http://127.0.0.1/private#old',
          'file:///etc/passwd',
        },
      ),
      ['https://example.org/valid.pdf'],
    );
  });
}
