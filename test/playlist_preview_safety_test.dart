import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/services/playlist_explorer.dart';

void main() {
  group('PlaylistExplorer preview limit', () {
    test('preserves valid limits and caps excessive requests', () {
      expect(PlaylistExplorer.boundedLimit(1), 1);
      expect(PlaylistExplorer.boundedLimit(37), 37);
      expect(PlaylistExplorer.boundedLimit(100), 100);
      expect(PlaylistExplorer.boundedLimit(101), 100);
      expect(PlaylistExplorer.boundedLimit(1000000), 100);
    });

    test('rejects zero and negative limits before network access', () {
      expect(() => PlaylistExplorer.boundedLimit(0), throwsRangeError);
      expect(() => PlaylistExplorer.boundedLimit(-1), throwsRangeError);
      expect(() => PlaylistExplorer.boundedLimit(-100), throwsRangeError);
    });
  });

  group('PlaylistExplorer thumbnail URLs', () {
    test('preserves public HTTPS thumbnails and signed query strings', () {
      const signed = 'https://i.ytimg.com/vi/abc/default.jpg?sig=a%2Bb%3D&expires=123';
      expect(PlaylistExplorer.safeThumbnailUrl(signed), signed);
      expect(
        PlaylistExplorer.safeThumbnailUrl('  https://cdn.example.com/thumb.png  '),
        'https://cdn.example.com/thumb.png',
      );
    });

    test('rejects unsafe schemes, credentials and private endpoints', () {
      for (final candidate in <String?>[
        null, '', ' ', 'javascript:alert(1)', 'file:///etc/passwd',
        'http://cdn.example.com/thumb.png',
        'https://localhost/thumb.png',
        'https://127.0.0.1/thumb.png',
        'https://192.168.1.10/thumb.png',
        'https://user:password@cdn.example.com/thumb.png',
        'https://cdn.example.com.evil.local/thumb.png',
        'https://[::1]/thumb.png',
      ]) {
        expect(PlaylistExplorer.safeThumbnailUrl(candidate), '',
            reason: 'Unsafe thumbnail URL: $candidate');
      }
    });

    test('rejects DNS and numeric aliases for loopback/private hosts', () {
      for (final candidate in <String>[
        'https://localhost./thumbnail.png',
        'https://127.1/thumbnail.png',
        'https://2130706433/thumbnail.png',
        'https://0x7f000001/thumbnail.png',
        'https://10.0.0.1/thumbnail.png',
        'https://169.254.1.2/thumbnail.png',
        'https://cdn.example.com.evil.internal/thumbnail.png',
      ]) {
        expect(PlaylistExplorer.safeThumbnailUrl(candidate), isEmpty,
            reason: 'Unsafe thumbnail alias: $candidate');
      }
      const publicCdn = 'https://cdn.example.com:443/thumb.jpg?sig=a%2Bb';
      expect(PlaylistExplorer.safeThumbnailUrl(publicCdn), publicCdn);
    });

  });
}
