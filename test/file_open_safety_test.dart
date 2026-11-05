import 'package:adnanload_mobile/core/file_open_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checks the on-disk path even when the display name looks harmless', () {
    expect(FileOpenSafety.requiresConfirmation(
      '/downloads/installer.APK', displayName: 'holiday.jpg'), isTrue);
    expect(FileOpenSafety.requiresConfirmation(
      r'C:\Downloads\setup.CMD', displayName: 'readme.txt'), isTrue);
  });

  test('also checks the displayed name when the stored path looks safe', () {
    expect(FileOpenSafety.requiresConfirmation(
      '/downloads/item.bin', displayName: 'installer.apk'), isTrue);
  });

  test('covers installer archives and scripts opened from folder listings', () {
    for (final name in [
      'app.apks', 'app.xapk', 'bundle.aab', 'tool.exe', 'tool.msi',
      'run.bat', 'run.ps1', 'run.sh', 'launch.jar', 'script.vbs',
    ]) {
      expect(FileOpenSafety.requiresConfirmation('/playlist/$name'), isTrue,
        reason: name);
    }
  });

  test('ignores hidden direction marks and trailing whitespace', () {
    expect(FileOpenSafety.requiresConfirmation(
      '/files/innocent\u202E.apk'), isTrue);
    expect(FileOpenSafety.requiresConfirmation('/files/install.apk  '), isTrue);
  });

  test('ordinary downloaded files open without a new confirmation', () {
    for (final name in [
      'movie.mp4', 'photo.jpg', 'report.pdf', 'archive.zip', 'notes.txt',
      'recording.m4a', 'package.apk.txt',
    ]) {
      expect(FileOpenSafety.requiresConfirmation(
        '/downloads/$name', displayName: name), isFalse, reason: name);
    }
  });
}
