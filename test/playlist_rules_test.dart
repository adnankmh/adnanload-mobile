import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/playlist_rules.dart';

void main() {
  test('recognizes the YouTube playlist endpoint', () {
    expect(PlaylistRules.looksLikePlaylist(
      'https://www.youtube.com/playlist?list=PLexample'), isTrue);
    expect(PlaylistRules.looksLikePlaylist(
      'https://www.youtube.com/watch?v=abc'), isFalse);
  });
  test('validates playlist item selections', () {
    expect(PlaylistRules.parseItems(' 1-10, 12, 15 '), '1-10,12,15');
    expect(PlaylistRules.parseItems(''), '');
    expect(() => PlaylistRules.parseItems('--exec malicious'), throwsFormatException);
    expect(() => PlaylistRules.parseItems('10-1'), throwsFormatException);
    expect(() => PlaylistRules.parseItems('0'), throwsFormatException);
  });
  test('media domain detection respects domain boundaries', () {
    expect(PlaylistRules.looksLikeMediaSite('https://m.youtube.com/abc'), isTrue);
    expect(PlaylistRules.looksLikeMediaSite('https://youtube.com.fake.net/'), isFalse);
  });
  test('YouTube playlists require one nonblank list identifier', () {
    expect(PlaylistRules.looksLikePlaylist(
      'https://www.youtube.com/playlist?list=PLvalid'), isTrue);
    expect(PlaylistRules.looksLikePlaylist(
      'https://music.youtube.com/playlist?list=PLmusic'), isTrue);
    for (final url in [
      'https://www.youtube.com/playlist',
      'https://www.youtube.com/playlist?list=',
      'https://www.youtube.com/playlist?list=%20%20',
      'https://www.youtube.com/playlist?list=PLone&list=PLtwo',
      'https://www.youtube.com/channel/abc?list=',
      'https://www.youtube.com/watch?v=abc&list=PLvalid',
    ]) {
      expect(PlaylistRules.looksLikePlaylist(url), isFalse, reason: url);
    }
  });

  test('non-HTTP pseudo URLs are not classified as playlists', () {
    expect(PlaylistRules.looksLikePlaylist(
      'javascript://youtube.com/playlist?list=PLvalid'), isFalse);
    expect(PlaylistRules.looksLikePlaylist(
      'file://youtube.com/playlist?list=PLvalid'), isFalse);
    expect(PlaylistRules.looksLikePlaylist(
      'https://soundcloud.com/artist/sets/demo'), isTrue);
    expect(PlaylistRules.looksLikePlaylist(
      'https://example.org/playlist/123'), isTrue);
  });

}
