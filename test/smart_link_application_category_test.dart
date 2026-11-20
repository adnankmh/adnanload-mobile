import 'package:adnanload_mobile/core/smart_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('URL fragments and queries do not disguise Android installers', () {
    for (final name in [
      'https://example.org/app.apk#details',
      'installer.APK?token=private#preview.jpg',
      'update.xapk#download',
      'bundle.apks?version=2',
      'package.aab#notes',
      'installer.apk#readme.txt',
    ]) {
      expect(SmartLink.category(name), 'application', reason: name);
    }
  });

  test('literal filenames containing fragment characters stay protected', () {
    for (final name in [
      'release#2026.apk',
      'release?build.apk',
      'report.pdf#installer.apk',
      'photo.jpg?signature=install.exe',
    ]) {
      expect(SmartLink.category(name), 'application', reason: name);
    }
  });

  test('ordinary file categories survive URL fragments and queries', () {
    expect(SmartLink.category('photo.JPG#preview'), 'image');
    expect(SmartLink.category('video.mp4?token=abc#start'), 'video');
    expect(SmartLink.category('report.pdf#page=2'), 'document');
    expect(SmartLink.category('song.flac?dl=1'), 'audio');
    expect(SmartLink.category('archive.zip#download'), 'archive');
    expect(SmartLink.category('unknown#fragment'), 'file');
  });

  test('literal filename with hash before extension retains its category', () {
    expect(SmartLink.category('holiday#2026.jpg'), 'image');
    expect(SmartLink.category('budget?draft.pdf'), 'document');
    expect(SmartLink.category('movie#final.mp4'), 'video');
  });
}
