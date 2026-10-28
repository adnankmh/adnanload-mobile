import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/app_strings.dart';
import 'package:adnanload_mobile/core/playlist_selection.dart';
import 'package:adnanload_mobile/core/media_detector.dart';
import 'package:adnanload_mobile/services/backup_service.dart';
import 'package:adnanload_mobile/models/download_entry.dart';

void main() {
  test('explicit playlist items become bounded independent jobs', () {
    expect(PlaylistSelection.expand('1-3,5,3'), [1,2,3,5]);
    expect(PlaylistSelection.expand(''),isEmpty);
    expect(()=>PlaylistSelection.expand('1-250'),throwsFormatException);
    expect(()=>PlaylistSelection.expand('5-3'),throwsFormatException);
  });

  test('only safe media candidates survive parsing', () {
    final raw=jsonEncode(['https://example.com/video.mp4',
      'https://example.com/video.mp4','http://localhost/private.mp4',
      'file:///data/secret','https://example.com/audio.mp3']);
    expect(MediaDetector.parse(raw),[
      'https://example.com/video.mp4','https://example.com/audio.mp3']);
    expect(MediaDetector.parse('not json'),isEmpty);
  });

  test('backup parser bounds and never restores active tasks', () {
    final item=DownloadEntry(id:'task1',url:'https://example.com/archive.zip',
      name:'../../archive.zip',kind:'direct',status:'running',
      addedAt:DateTime.now().millisecondsSinceEpoch,
      autoQueue:true,nativeQueued:true,path:'/private/secret');
    final archive=BackupService.create(items:[item],bookmarks:['https://example.com'],
      theme:'gold',language:'ar',wifiOnly:false);
    final parsed=BackupService.parse(jsonEncode(archive));
    final entries=BackupService.validEntries(parsed);
    expect(entries,hasLength(1));
    expect(entries.single.path,isEmpty);
    expect(entries.single.name, isNot(contains('/')));
    expect(entries.single.status,'waiting');
    expect(entries.single.autoQueue,false);
    expect(entries.single.id, isNot('task1'));
    expect(()=>BackupService.parse('{"schema":1}'),throwsFormatException);
  });

  test('V1.4 feature labels are bilingual', () {
    expect(AppStrings.ar.keys.toSet(),AppStrings.en.keys.toSet());
    for(final key in ['amoled','glass','pinLock','backupImport','backupExport',
      'detectedMedia','duplicateScan','autoEngineUpdates','separatePlaylistItems']) {
      expect(AppStrings.ar[key],isNotNull);
      expect(AppStrings.en[key],isNotNull);
    }
  });
}
