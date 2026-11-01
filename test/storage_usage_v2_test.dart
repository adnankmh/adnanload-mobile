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

  test('counts each physical file once across path and symlink aliases', () async {
    final dir = await Directory.systemTemp.createTemp('adnanload-alias-test-');
    try {
      final original = File('${dir.path}/original.bin');
      final separate = File('${dir.path}/separate.bin');
      final nested = Directory('${dir.path}/nested');
      await nested.create();
      await original.writeAsBytes([1, 2, 3, 4]);
      await separate.writeAsBytes([5, 6, 7]);
      final alias = Link('${dir.path}/alias.bin');
      await alias.create(original.path);

      DownloadEntry completed(String id, String path) => DownloadEntry(
        id: id,
        url: 'https://example.org/file.bin',
        name: 'file.bin',
        kind: 'direct',
        status: 'complete',
        path: path,
        addedAt: 1,
      );
      final total = await StorageAudit.recordedBytes([
        completed('original', original.path),
        completed('dot-alias', '${nested.path}/../original.bin'),
        completed('symlink-alias', alias.path),
        completed('separate', separate.path),
      ]);
      expect(total, 7);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
