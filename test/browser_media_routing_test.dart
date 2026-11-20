import 'dart:convert';

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

  test('DOM fragments do not duplicate a signed media URL', () {
    final links = MediaDetector.parse(jsonEncode([
      'https://cdn.example.com/a.mp4?token=ab%23cd%3Bef#start=1',
      'https://cdn.example.com/a.mp4?token=ab%23cd%3Bef#start=30',
      'https://cdn.example.com/a.mp4?token=ab%23cd%3Bef',
      'https://cdn.example.com/a.mp4?token=ab%23cd%3Bother#start=1',
    ]));
    expect(links, [
      'https://cdn.example.com/a.mp4?token=ab%23cd%3Bef',
      'https://cdn.example.com/a.mp4?token=ab%23cd%3Bother',
    ]);
  });

  test('fragment variants do not consume the 12-candidate DOM budget', () {
    final links = MediaDetector.parse(jsonEncode([
      for (var i = 0; i < 11; i++)
        'https://cdn.example.org/file$i.mp4#player',
      'https://cdn.example.org/file0.mp4#other',
      'https://cdn.example.org/last.mp4#player',
    ]));
    expect(links.length, 12);
    expect(links.last, 'https://cdn.example.org/last.mp4');
    // The browser-side probe must deduplicate before its own cap as well.
    final probe = MediaDetector.domProbe;
    expect(probe.indexOf("u.hash = '';"), lessThan(probe.indexOf('found.add(u.href)')));
  });

  test('double-encoded WebView results also deduplicate fragments', () {
    final payload = jsonEncode([
      'https://cdn.example.org/a.mp4#first',
      'https://cdn.example.org/a.mp4#second',
    ]);
    expect(MediaDetector.parse(jsonEncode(payload)), [
      'https://cdn.example.org/a.mp4',
    ]);
  });
}
