import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/models/download_entry.dart';

void main() {
  test('playlist options survive history round trip', () {
    final item = DownloadEntry(id:'a',url:'https://example.org/playlists/123',
      name:'Travel',kind:'mp3',status:'waiting',addedAt:1,
      isPlaylist:true,playlistItems:'1:10,12',audioFormat:'flac');
    final restored=DownloadEntry.fromJson(item.toJson());
    expect(restored.isPlaylist,isTrue);
    expect(restored.playlistItems,'1:10,12');
    expect(restored.audioFormat,'flac');
  });
  test('older downloads have compatible playlist defaults', () {
    final old=DownloadEntry.fromJson({'id':'old','url':'https://example.org/a',
      'name':'a','kind':'direct','status':'complete','addedAt':1});
    expect(old.isPlaylist,isFalse);
    expect(old.playlistItems,isEmpty);
  });
}
