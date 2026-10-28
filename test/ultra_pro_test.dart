import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/app_strings.dart';
import 'package:adnanload_mobile/core/url_guard.dart';
import 'package:adnanload_mobile/models/download_entry.dart';

void main() {
  test('V1.3 download metadata survives serialization', () {
    final item = DownloadEntry(id:'t1',url:'https://example.com/file.zip',name:'file.zip',
      kind:'direct',status:'waiting',quality:'best',addedAt:42,
      expectedSha256:'a' * 64, scheduledAt:300000, autoQueue:true,
      nativeQueued:false,priority:0);
    final restored=DownloadEntry.fromJson(item.toJson());
    expect(restored.expectedSha256, 'a' * 64);
    expect(restored.scheduledAt,300000);
    expect(restored.autoQueue,true);
    expect(restored.nativeQueued,false);
    expect(restored.priority,0);
  });

  test('new UI keys have exact language coverage', () {
    expect(AppStrings.ar.keys.toSet(), AppStrings.en.keys.toSet());
    for (final k in ['mediaPreview','verifyHash','exportDownloads','renameFile',
      'scheduleDownload','maxConcurrent','parallelParts','openBookmarks',
      'engineUpdateSuccess','fileSafety']) {
      expect(AppStrings.ar.containsKey(k),true);
      expect(AppStrings.en.containsKey(k),true);
    }
  });

  test('remote-only URLs and filename normalization', () {
    expect(UrlGuard.validate('file:///data/secret'), isNull);
    expect(UrlGuard.validate('http://localhost/admin'), isNull);
    expect(UrlGuard.validate('http://192.168.1.1/'), isNull);
    expect(UrlGuard.validate('https://example.com/document.pdf'), isNotNull);
    expect(UrlGuard.safeName('../some:file?.zip'), isNot(contains('/')));
  });
}
