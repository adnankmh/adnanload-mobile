import 'package:adnanload_mobile/core/batch_link_preview.dart';
import 'package:adnanload_mobile/core/batch_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('direct link previews decoded, sanitized filename without query', () {
    final item = BatchLinkPreview.fromUrl(
      'https://example.org/%D9%85%D9%84%D9%81.pdf?token=private',
    );
    expect(item.url, contains('token=private'));
    expect(item.host, 'example.org');
    expect(item.suggestedName, 'ملف.pdf');
    expect(item.kind, 'direct');
    expect(item.isPlaylist, isFalse);
  });

  test('page and extensionless downloads do not invent filenames', () {
    expect(BatchLinkPreview.fromUrl('https://example.org/get?id=12')
        .suggestedName, isNull);
    expect(BatchLinkPreview.fromUrl('https://www.youtube.com/watch?v=abc')
        .suggestedName, isNull);
  });

  test('playlist routes to video queue but retains playlist flag', () {
    final item = BatchLinkPreview.fromUrl(
      'https://www.youtube.com/playlist?list=PL123456',
    );
    expect(item.kind, 'video');
    expect(item.isPlaylist, isTrue);
    expect(item.suggestedName, isNull);
  });

  test('preferred media mode is reflected in preview', () {
    expect(BatchLinkPreview.fromUrl(
      'https://www.youtube.com/watch?v=abc', preferred: 'mp3',
    ).kind, 'mp3');
    expect(BatchLinkPreview.fromUrl(
      'https://example.org/archive.zip', preferred: 'mp3',
    ).kind, 'direct');
  });

  test('unsafe URLs cannot be previewed', () {
    for (final url in [
      'file:///tmp/secret',
      'http://127.0.0.1/private',
      'http://localhost/private',
      'https://user:pass@example.org/file.zip',
    ]) {
      expect(() => BatchLinkPreview.fromUrl(url), throwsFormatException);
    }
  });

  test('preview uses the same accepted, deduplicated batch links', () {
    final links = BatchLinks.parse(
      'https://example.org/a.zip\nhttps://example.org/a.zip\n'
      'http://127.0.0.1/admin\nhttps://example.org/b.pdf',
    );
    final previews = links.map(BatchLinkPreview.fromUrl).toList();
    expect(previews.map((p) => p.suggestedName),
        ['a.zip', 'b.pdf']);
  });
}
