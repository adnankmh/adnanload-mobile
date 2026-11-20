import 'package:adnanload_mobile/core/file_open_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalized desktop installers require confirmation', () {
    for (final name in [
      'package.d\u200Beb',
      'package.r\u202Epm',
      'installer.dmg...',
      'package.deb... #notes',
      'installer.d\u200Bmg?token=abc',
    ]) {
      expect(FileOpenSafety.requiresConfirmation('/downloads/$name',
          displayName: 'safe.pdf'), isTrue, reason: name);
      expect(FileOpenSafety.mayAutoOpen('/downloads/safe.pdf',
          displayName: name), isFalse, reason: name);
    }
  });

  test('ordinary documents with package-like names remain safe', () {
    for (final name in ['package.deb.txt', 'installer.dmg.pdf', 'report.rpm.csv']) {
      expect(FileOpenSafety.mayAutoOpen('/downloads/$name',
          displayName: name), isTrue, reason: name);
    }
  });
}
