import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/app_strings.dart';
import 'package:adnanload_mobile/services/media_converter.dart';

void main(){
  test('supported offline conversion destinations',(){
    expect(MediaConverter.validFormat('MP3'),isTrue);
    expect(MediaConverter.validFormat('mp4'),isTrue);
    expect(MediaConverter.validFormat('exe'),isFalse);
  });
  test('v2 translated controls',(){
    for(final key in ['batchTitle','batchAdd','playlistExplore','convertMedia',
      'storageLimit','healthCenter']){
      expect(AppStrings.ar[key],isNotNull);
      expect(AppStrings.en[key],isNotNull);
    }
  });
}
