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
 test('incoming media pages are extracted; direct files stay direct', () {
  expect(SmartLink.incomingKind('https://youtu.be/abc123'), 'video');
  expect(SmartLink.incomingKind('https://www.youtube.com/watch?v=abc123'), 'video');
  expect(SmartLink.incomingKind('https://www.youtube.com/playlist?list=PL123'), 'video');
  expect(SmartLink.incomingKind('https://www.instagram.com/reel/abc123/'), 'video');
  expect(SmartLink.incomingKind('https://example.com/book.pdf'), 'direct');
  expect(SmartLink.incomingKind('https://example.com/photo.jpg'), 'direct');
  expect(SmartLink.incomingKind('https://youtu.be/abc123', requested:'mp3'), 'mp3');
  expect(SmartLink.incomingKind('https://youtube.com.evil.example/watch?v=abc'), 'direct');
 });
 test('extension classification distinguishes file types', () {
  expect(SmartLink.category('photo.jpg'),'image');
  expect(SmartLink.category('setup.apk'),'application');
  expect(SmartLink.category('work.docx'),'document');
  expect(SmartLink.category('audio.m4a'),'audio');
  expect(SmartLink.category('movie.mp4'),'video');
 });
}
