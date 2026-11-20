import 'package:adnanload_mobile/core/batch_link_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('double-encoded path separators do not become suggested filenames', () {
    for (final url in [
      'https://example.org/folder%252Fhidden.pdf',
      'https://example.org/folder%255Chidden.zip',
      'https://example.org/folder%252fhidden.mp4',
      'https://example.org/folder%255chidden.apk',
    ]) {
      final preview = BatchLinkPreview.fromUrl(url);
      expect(preview.kind, 'direct', reason: url);
      expect(preview.suggestedName, isNull, reason: url);
      expect(preview.url, url, reason: url);
    }
  });

  test('additional percent-encoding layers cannot spoof a filename', () {
    for (final url in [
      'https://example.org/a%25252Fsecret.pdf',
      'https://example.org/a%2525255csecret.zip',
    ]) {
      expect(BatchLinkPreview.fromUrl(url).suggestedName, isNull,
          reason: url);
    }
  });

  test('signed queries are retained even when preview name is suppressed', () {
    const url =
        'https://cdn.example.org/a%252Fhidden.pdf?signature=AB%2FCD%2B12';
    final preview = BatchLinkPreview.fromUrl(url);
    expect(preview.url, url);
    expect(preview.host, 'cdn.example.org');
    expect(preview.suggestedName, isNull);
  });

  test('ordinary escaped filenames and literal percent signs still preview', () {
    expect(
      BatchLinkPreview.fromUrl(
        'https://example.org/final%20report.pdf?sig=AB%2FCD',
      ).suggestedName,
      'final report.pdf',
    );
    expect(
      BatchLinkPreview.fromUrl(
        'https://example.org/report%25complete.pdf',
      ).suggestedName,
      'report%complete.pdf',
    );
  });
}
