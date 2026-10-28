import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/smart_link.dart';
void main() {
 test('auto route respects direct files, playlist and media sites', () {
  expect(SmartLink.kind('https://example.com/file.pdf'), 'direct');
  expect(SmartLink.kind('https://example.com/movie.mp4?token=x'), 'direct');
  expect(SmartLink.kind('https://www.youtube.com/watch?v=abc123'), 'video');
  expect(SmartLink.kind('https://www.youtube.com/playlist?list=PL123456'), 'playlist');
  expect(SmartLink.kind('https://example.com/archive.zip', preferred:'video'),'direct');
 });
 test('extension classification distinguishes file types', () {
  expect(SmartLink.category('photo.jpg'),'image');
  expect(SmartLink.category('setup.apk'),'application');
  expect(SmartLink.category('work.docx'),'document');
  expect(SmartLink.category('audio.m4a'),'audio');
  expect(SmartLink.category('movie.mp4'),'video');
 });
}
