import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:adnanload_mobile/models/download_entry.dart';
import 'package:flutter_test/flutter_test.dart';

DownloadEntry queued({
  String status = 'waiting',
  bool autoQueue = true,
  bool scheduledExternally = false,
  int scheduledAt = 0,
  int retryAt = 0,
}) => DownloadEntry(
  id: 'queued-job', url: 'https://example.org/file.zip',
  name: 'file.zip', kind: 'direct', status: status, addedAt: 1,
  autoQueue: autoQueue, scheduledExternally: scheduledExternally,
  scheduledAt: scheduledAt, retryAt: retryAt,
);

void main() {
  const now = 2000000;

  test('eligible queued work is runnable without changing its metadata', () {
    final item = queued();
    final before = item.toJson();
    expect(TransferPolicy.readyToDispatch(item, now), isTrue);
    expect(item.toJson(), before);
  });

  test('pause, cancellation, verification and completion beat stale snapshots', () {
    final item = queued();
    expect(TransferPolicy.readyToDispatch(item, now), isTrue);
    for (final status in <String>[
      'paused', 'canceled', 'error', 'running', 'submitting',
      'verifying', 'complete',
    ]) {
      item.status = status;
      expect(TransferPolicy.readyToDispatch(item, now), isFalse,
          reason: status);
    }
  });

  test('a user-deferred entry cannot be auto-started', () {
    final item = queued(autoQueue: false);
    expect(TransferPolicy.readyToDispatch(item, now), isFalse);
    item.autoQueue = true;
    expect(TransferPolicy.readyToDispatch(item, now), isTrue);
  });

  test('external Android schedules retain WorkManager ownership', () {
    final item = queued(scheduledExternally: true);
    expect(TransferPolicy.readyToDispatch(item, now), isFalse);
  });

  test('future schedule and retry backoff are both respected at dispatch', () {
    final item = queued(scheduledAt: now + 1, retryAt: now + 2);
    expect(TransferPolicy.readyToDispatch(item, now), isFalse);
    expect(TransferPolicy.readyToDispatch(item, now + 1), isFalse);
    expect(TransferPolicy.readyToDispatch(item, now + 2), isTrue);
    item.scheduledAt = now + 100;
    expect(TransferPolicy.readyToDispatch(item, now + 2), isFalse);
  });

  test('stale snapshot cannot override pause or removal after an await', () async {
    final item = queued();
    final queue = <DownloadEntry>[item];
    final snapshot = queue.where(
      (job) => TransferPolicy.readyToDispatch(job, now),
    ).toList();
    expect(snapshot, contains(item));
    await Future<void>.delayed(Duration.zero);
    item.status = 'paused';
    item.autoQueue = false;
    expect(queue.contains(item) && TransferPolicy.readyToDispatch(item, now),
        isFalse);
    item.status = 'waiting';
    item.autoQueue = true;
    queue.clear();
    expect(queue.contains(item) && TransferPolicy.readyToDispatch(item, now),
        isFalse);
  });
}
