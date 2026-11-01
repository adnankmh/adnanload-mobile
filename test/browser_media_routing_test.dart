import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/media_detector.dart';

void main() {
  test('direct video and audio URLs remain native downloads', () {
    for (final url in [
      'https://cdn.example.com/movie.mp4?token=temporary',
      'https://cdn.example.com/audio.webm?download=1',
      'https://cdn.example.com/song.m4a',
      'https://cdn.example.com/file.MP3?expires=42',
    ]) {
      expect(MediaDetector.detectedDownloadKind(url), 'direct');
    }
  });

  test('streaming manifests require the media engine', () {
    expect(MediaDetector.detectedDownloadKind(
      'https://cdn.example.com/master.m3u8?sig=example'), 'video');
    expect(MediaDetector.detectedDownloadKind(
      'https://cdn.example.com/stream.MPD'), 'video');
  });

  test('public media pages use extraction, lookalikes stay direct', () {
    expect(MediaDetector.detectedDownloadKind(
      'https://www.youtube.com/watch?v=example'), 'video');
    expect(MediaDetector.detectedDownloadKind(
      'https://www.instagram.com/reel/example/'), 'video');
    expect(MediaDetector.detectedDownloadKind(
      'https://youtube.com.evil.example/watch?v=example'), 'direct');
    expect(MediaDetector.detectedDownloadKind(
      'https://cdn.example.com/opaque-endpoint'), 'direct');
  });

  test('DOM parser rejects private URLs and duplicate links', () {
    final links = MediaDetector.parse(
      '["https://cdn.example.com/a.mp4",'
      '"https://cdn.example.com/a.mp4",'
      '"http://127.0.0.1/private",'
      '"file:///sdcard/private.mp4"]');
    expect(links, ['https://cdn.example.com/a.mp4']);
  });
}
