import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:adnanload_mobile/models/download_entry.dart';

DownloadEntry entry({String kind = 'direct', String status = 'paused',
    bool nativeQueued = false, bool scheduledExternally = false}) =>
  DownloadEntry(id: 'job', url: 'https://example.org/file', name: 'file',
    kind: kind, status: status, addedAt: 1, autoQueue: false,
    nativeQueued: nativeQueued, scheduledExternally: scheduledExternally,
    retryAt: 123456, scheduledAt: 987654);

void main() {
  test('locally paused direct download returns to the runnable queue', () {
    final item = entry();
    expect(TransferPolicy.requeueDeferredDirect(item), isTrue);
    expect(item.status, 'waiting');
    expect(item.autoQueue, isTrue);
    expect(item.retryAt, 0);
    expect(item.scheduledAt, 0);
  });

  test('manual start of deferred waiting download clears future schedule', () {
    final item = entry(status: 'waiting');
    expect(TransferPolicy.requeueDeferredDirect(item), isTrue);
    expect(item.status, 'waiting');
    expect(item.autoQueue, isTrue);
    expect(item.scheduledAt, 0);
  });

  test('native paused task is never submitted as a second download', () {
    final item = entry(nativeQueued: true);
    expect(TransferPolicy.requeueDeferredDirect(item), isFalse);
    expect(item.status, 'paused');
    expect(item.autoQueue, isFalse);
    expect(item.retryAt, 123456);
  });

  test('externally scheduled Android job remains owned by WorkManager', () {
    final item = entry(scheduledExternally: true);
    expect(TransferPolicy.requeueDeferredDirect(item), isFalse);
    expect(item.status, 'paused');
    expect(item.scheduledAt, 987654);
  });

  test('completed, canceled, running and failed jobs cannot be requeued', () {
    for (final status in ['complete', 'canceled', 'running', 'error']) {
      final item = entry(status: status);
      expect(TransferPolicy.requeueDeferredDirect(item), isFalse, reason: status);
      expect(item.status, status);
      expect(item.autoQueue, isFalse);
    }
  });

  test('media jobs are not restarted through the native direct queue', () {
    final item = entry(kind: 'video');
    expect(TransferPolicy.requeueDeferredDirect(item), isFalse);
    expect(item.status, 'paused');
    expect(item.autoQueue, isFalse);
  });
}
