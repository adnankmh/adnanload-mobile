import 'package:adnanload_mobile/core/batch_link_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HTML pages and dynamic endpoints do not invent file names', () {
    for (final url in [
      'https://example.org/index.html',
      'https://example.org/article.HTM?print=1',
      'https://example.org/help.xhtml',
      'https://example.org/download.php?file=report.pdf',
      'https://example.org/export.PHP5?type=zip',
      'https://example.org/item.aspx?id=4',
      'https://example.org/view.jsp?name=archive.zip',
    ]) {
      final preview = BatchLinkPreview.fromUrl(url);
      expect(preview.kind, 'direct', reason: url);
      expect(preview.suggestedName, isNull, reason: url);
    }
  });

  test('encoded path separators do not spoof a last-segment filename', () {
    for (final url in [
      'https://example.org/files%2Fhidden.pdf',
      'https://example.org/files%5Chidden.zip',
    ]) {
      expect(BatchLinkPreview.fromUrl(url).suggestedName, isNull,
          reason: url);
    }
  });

  test('genuine file names and signed URLs are preserved', () {
    const url = 'https://example.org/reports/Report.PDF?token=abc%2F123';
    final preview = BatchLinkPreview.fromUrl(url);
    expect(preview.url, url);
    expect(preview.host, 'example.org');
    expect(preview.kind, 'direct');
    expect(preview.suggestedName, 'Report.PDF');

    expect(
      BatchLinkPreview.fromUrl('https://example.org/archive.zip')
          .suggestedName,
      'archive.zip',
    );
  });

  test('extensionless download endpoints still await server metadata', () {
    final preview = BatchLinkPreview.fromUrl(
      'https://example.org/download?id=report.pdf',
    );
    expect(preview.suggestedName, isNull);
  });
}
