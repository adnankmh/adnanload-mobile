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
}
