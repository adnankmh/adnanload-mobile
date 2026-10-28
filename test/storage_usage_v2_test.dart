import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/models/download_entry.dart';
import 'package:adnanload_mobile/services/storage_audit.dart';

void main(){
  test('only complete unique files count toward app limit',() async {
    final dir=await Directory.systemTemp.createTemp('adnanload-v2-test');
    try {
      final file=File('${dir.path}${Platform.pathSeparator}test.bin');
      await file.writeAsBytes(List<int>.filled(10,42));
      DownloadEntry create(String id,String status)=>DownloadEntry(
        id:id,url:'https://example.org/test.bin',name:'test.bin',kind:'direct',
        status:status,path:file.path,addedAt:1);
      final size=await StorageAudit.recordedBytes([
        create('1','complete'),create('2','complete'),create('3','error')]);
      expect(size,10);
    } finally {await dir.delete(recursive:true);}
  });
}
