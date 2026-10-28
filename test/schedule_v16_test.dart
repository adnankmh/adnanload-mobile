import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/models/download_entry.dart';
import 'package:adnanload_mobile/services/backup_service.dart';
import 'package:adnanload_mobile/services/android_schedule_service.dart';

void main() {
  test('Android unique scheduler names are stable', () {
    expect(scheduledWorkId('adnan_1'), 'adnanload.direct.adnan_1');
    expect(scheduledWorkId('adnan_1'), isNot(scheduledWorkId('adnan_2')));
  });

  test('Scheduled native state survives JSON round trip', () {
    final job = DownloadEntry(id:'adnan_1', url:'https://example.org/a.bin',
      name:'a.bin', kind:'direct', status:'waiting',
      addedAt:123, autoQueue:false, scheduledAt:2000,
      scheduledExternally:true);
    final restored = DownloadEntry.fromJson(job.toJson());
    expect(restored.scheduledExternally, isTrue);
    expect(restored.autoQueue, isFalse);
    expect(restored.scheduledAt, 2000);
  });

  test('Imported backup cannot silently revive a scheduled job', () {
    final original = DownloadEntry(id:'adnan_1',
      url:'https://example.org/a.bin', name:'a.bin', kind:'direct',
      status:'waiting', addedAt:123, scheduledAt:2000,
      scheduledExternally:true);
    final backup = BackupService.create(items:[original], bookmarks:[],
      theme:'neon', language:'ar', wifiOnly:false);
    final imported = BackupService.validEntries(backup).single;
    expect(imported.scheduledExternally, isFalse);
    expect(imported.scheduledAt, 0);
    expect(imported.autoQueue, isFalse);
  });
}
