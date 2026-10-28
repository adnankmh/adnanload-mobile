import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/app_strings.dart';

void main(){
  test('Arabic and English keys are identical', () {
    expect(AppStrings.ar.keys.toSet(), AppStrings.en.keys.toSet());
  });
  test('all translation keys have values', () {
    for (final v in AppStrings.en.values) {expect(v.trim(), isNotEmpty);}
    for (final v in AppStrings.ar.values) {expect(v.trim(), isNotEmpty);}
  });
}
