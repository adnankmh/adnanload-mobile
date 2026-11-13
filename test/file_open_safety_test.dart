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

  test('prompts for Windows executable shortcuts and scripts', () {
    for (final name in [
      'setup.com', 'screen.scr', 'run.hta', 'task.wsf',
      'link.pif', 'panel.cpl', 'settings.reg', 'shortcut.lnk',
    ]) {
      expect(FileOpenSafety.requiresConfirmation('/downloads/$name'), isTrue,
        reason: name);
    }
  });

  test('trailing dots cannot hide an installer extension', () {
    expect(FileOpenSafety.requiresConfirmation('/downloads/install.apk.'), isTrue);
    expect(FileOpenSafety.requiresConfirmation(
      '/downloads/run.cmd...   '), isTrue);
    expect(FileOpenSafety.requiresConfirmation('/downloads/report.pdf.'), isFalse);
    expect(FileOpenSafety.requiresConfirmation('/downloads/archive.tar.gz'), isFalse);
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

  test('auto-open rejects an installer hidden behind a harmless display name', () {
    expect(FileOpenSafety.mayAutoOpen(
      '/downloads/payload.apk', displayName: 'photo.jpg'), isFalse);
    expect(FileOpenSafety.mayAutoOpen(
      '/downloads/photo.jpg', displayName: 'payload.apk'), isFalse);
    expect(FileOpenSafety.mayAutoOpen(
      '/downloads/payload.apk?token=abc', displayName: 'photo.jpg'), isFalse);
  });

  test('manual open confirms all installer formats blocked by auto-open', () {
    for (final name in ['package.deb', 'package.rpm', 'installer.dmg']) {
      expect(FileOpenSafety.requiresConfirmation(
        '/downloads/$name', displayName: 'safe.pdf'), isTrue,
        reason: 'physical path: $name');
      expect(FileOpenSafety.requiresConfirmation(
        '/downloads/safe.pdf', displayName: name), isTrue,
        reason: 'display name: $name');
      expect(FileOpenSafety.mayAutoOpen(
        '/downloads/$name', displayName: 'safe.pdf'), isFalse,
        reason: name);
    }
  });

  test('manual open cannot hide installers behind URL-style suffixes', () {
    for (final name in [
      'setup.apk?token=private',
      'installer.exe#notes',
      'bundle.aab?download=1#info',
      'release#2026.apk',
      'release?build.dmg',
    ]) {
      expect(FileOpenSafety.requiresConfirmation(
        '/downloads/$name', displayName: 'safe.pdf'), isTrue,
        reason: 'physical path: $name');
      expect(FileOpenSafety.requiresConfirmation(
        '/downloads/safe.pdf', displayName: name), isTrue,
        reason: 'display name: $name');
    }
  });

  test('manual open keeps harmless query and fragment names unprompted', () {
    for (final name in [
      'report.pdf?token=private',
      'archive.zip#part2',
      'photo.jpg?version=2026',
    ]) {
      expect(FileOpenSafety.requiresConfirmation(
        '/downloads/$name', displayName: name), isFalse,
        reason: name);
    }
  });

  test('auto-open rejects application packages outside Android APK formats', () {
    for (final name in ['bundle.deb', 'installer.rpm', 'app.dmg']) {
      expect(FileOpenSafety.mayAutoOpen(
        '/downloads/$name', displayName: 'safe.pdf'), isFalse, reason: name);
    }
  });


  test('warns before opening Windows package bundles and patch installers', () {
    for (final name in [
      'store.appx', 'bundle.appxbundle', 'installer.msix',
      'bundle.msixbundle', 'patch.msp',
    ]) {
      expect(FileOpenSafety.requiresConfirmation(
        '/downloads/$name', displayName: 'safe.pdf'), isTrue,
        reason: 'physical: $name');
      expect(FileOpenSafety.mayAutoOpen(
        '/downloads/safe.pdf', displayName: name), isFalse,
        reason: 'display: $name');
    }
  });

  test('requires opt-in for executable scripts and shortcut launchers', () {
    for (final name in [
      'module.psm1', 'script.vbe', 'script.js', 'script.jse',
      'launcher.ws', 'launcher.wsh', 'task.sct', 'folder.scf',
      'launch.command', 'launcher.desktop', 'shortcut.url',
    ]) {
      expect(FileOpenSafety.requiresConfirmation(
        '/downloads/$name', displayName: 'readme.txt'), isTrue,
        reason: name);
      expect(FileOpenSafety.mayAutoOpen(
        '/downloads/$name', displayName: 'readme.txt'), isFalse,
        reason: name);
    }
  });

  test('new extension guards ignore harmless suffixes and hidden marks', () {
    for (final name in [
      'script.js.map', 'package.msix.txt', 'launcher.desktop.pdf',
    ]) {
      expect(FileOpenSafety.requiresConfirmation(
        '/downloads/$name', displayName: name), isFalse,
        reason: name);
    }
    expect(FileOpenSafety.requiresConfirmation(
      '/downloads/install.m\u200Bsix'), isTrue);
    expect(FileOpenSafety.requiresConfirmation(
      '/downloads/launcher.desktop...  '), isTrue);
  });

  test('script and shortcut suffixes cannot bypass open confirmation', () {
    for (final name in [
      'run.cmd?download=1', 'script.js#notes', 'shortcut.lnk?x=1',
      'launch.p\u200Bs1?token=abc', 'run.bat... #notes',
    ]) {
      expect(FileOpenSafety.requiresConfirmation(
        '/downloads/$name', displayName: 'safe.pdf'), isTrue,
        reason: name);
      expect(FileOpenSafety.mayAutoOpen(
        '/downloads/safe.pdf', displayName: name), isFalse,
        reason: name);
    }
    for (final name in ['script.js.map?x=1', 'report.pdf#notes']) {
      expect(FileOpenSafety.mayAutoOpen(
        '/downloads/$name', displayName: name), isTrue, reason: name);
    }
  });

  test('auto-open preserves safe files and refuses missing paths', () {
    expect(FileOpenSafety.mayAutoOpen(
      '/downloads/report.pdf', displayName: 'report.pdf'), isTrue);
    expect(FileOpenSafety.mayAutoOpen(
      '/downloads/movie.mp4', displayName: 'movie.mp4'), isTrue);
    expect(FileOpenSafety.mayAutoOpen('', displayName: 'report.pdf'), isFalse);
  });
}
