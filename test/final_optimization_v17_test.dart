import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/url_guard.dart';
import 'package:adnanload_mobile/core/playlist_selection.dart';
import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:adnanload_mobile/models/download_entry.dart';

void main() {
  test('safe file name preserves UTF-8 while blocking slash traversal', () {
    expect(UrlGuard.safeName('../malicious.zip'), '.._malicious.zip');
    expect(UrlGuard.safeName('تقرير 2026.pdf'), 'تقرير 2026.pdf');
    expect(UrlGuard.nameFromUrl('https://example.org/my%20file%25.pdf'), 'my file%.pdf');
  });
  test('independent playlist jobs are bounded and ordered', () {
    expect(PlaylistSelection.expand('3,1-2,2'), [1,2,3]);
    expect(() => PlaylistSelection.expand('1-101'), throwsFormatException);
  });
  test('offline, WiFi and battery rules are fail closed', () {
    expect(TransferPolicy.mayStart(wifiOnly:true, hasWifi:false,
      hasNetwork:true,batteryPercent:100,charging:true,batteryFloor:25),isFalse);
    expect(TransferPolicy.mayStart(wifiOnly:false, hasWifi:false,
      hasNetwork:false,batteryPercent:100,charging:true,batteryFloor:25),isFalse);
    expect(TransferPolicy.mayStart(wifiOnly:false, hasWifi:false,
      hasNetwork:true,batteryPercent:9,charging:false,batteryFloor:25),isFalse);
  });
  test('download entry serialization retains pending, paused and playlist data', () {
    final item=DownloadEntry(id:'x1',url:'https://example.org/video',name:'Clip',
      kind:'video',status:'paused',addedAt:100,priority:2,
      isPlaylist:true,playlistItems:'2,4',autoQueue:false);
    final copy=DownloadEntry.fromJson(item.toJson());
    expect(copy.status,'paused');
    expect(copy.isPlaylist,isTrue);
    expect(copy.playlistItems,'2,4');
    expect(copy.priority,2);
  });
}
