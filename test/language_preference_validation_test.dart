import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/language_preference.dart';

void main() {
  test('only UI-supported language codes are accepted', () {
    expect(LanguagePreference.supported, ['ar', 'en']);
    expect(LanguagePreference.isSupported('ar'), isTrue);
    expect(LanguagePreference.isSupported('en'), isTrue);
    for (final invalid in <String?>[null, '', 'fr', 'AR', 'en-US', ' ar ']) {
      expect(LanguagePreference.isSupported(invalid), isFalse);
    }
  });

  test('corrupted preference types and hidden characters fail closed', () {
    for (final invalid in <Object?>[
      42,
      true,
      <String>['en'],
      <String, String>{'language': 'en'},
      'en\u200b',
      'en\n',
      '\u202een',
      'en_US',
    ]) {
      expect(LanguagePreference.isSupported(invalid), isFalse,
          reason: '$invalid');
      expect(LanguagePreference.normalize(invalid), 'ar',
          reason: '$invalid');
    }
  });

  test('restored invalid language preferences fall back to Arabic', () {
    expect(LanguagePreference.normalize('ar'), 'ar');
    expect(LanguagePreference.normalize('en'), 'en');
    for (final invalid in <String?>[null, '', 'fr', 'AR', 'en-US', ' ar ']) {
      expect(LanguagePreference.normalize(invalid), 'ar');
    }
  });
}
