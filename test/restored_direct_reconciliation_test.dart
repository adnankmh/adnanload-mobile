import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:adnanload_mobile/models/download_entry.dart';

DownloadEntry restored({String kind = 'direct', String status = 'waiting',
    bool nativeQueued = false, bool scheduledExternally = false,
    bool autoQueue = true}) => DownloadEntry(
  id: 'restored-job', url: 'https://example.org/archive.zip',
  name: 'archive.zip', kind: kind, status: status, addedAt: 1,
  nativeQueued: nativeQueued, scheduledExternally: scheduledExternally,
  autoQueue: autoQueue, scheduledAt: 123, retryAt: 456,
);

void main() {
  test('existing native job is recovered even when queued flag was not saved', () {
    final item = restored(status: 'running');
    TransferPolicy.reconcileRestoredDirect(item, nativeTaskExists: true);
    expect(item.nativeQueued, isTrue);
    expect(item.status, 'running');
    expect(item.autoQueue, isFalse);
  });

  test('restored native paused job remains paused and resumable', () {
    final item = restored(status: 'paused', autoQueue: false);
    TransferPolicy.reconcileRestoredDirect(item, nativeTaskExists: true);
    expect(item.nativeQueued, isTrue);
    expect(item.status, 'paused');
    expect(item.autoQueue, isFalse);
  });

  test('submitting with native job does not enqueue duplicate on restart', () {
    final item = restored(status: 'submitting', autoQueue: false);
    TransferPolicy.reconcileRestoredDirect(item, nativeTaskExists: true);
    expect(item.status, 'waiting');
    expect(item.nativeQueued, isTrue);
    expect(item.autoQueue, isFalse);
  });

  test('submitting without native job preserves existing safe requeue', () {
    final item = restored(status: 'submitting', autoQueue: false);
    TransferPolicy.reconcileRestoredDirect(item, nativeTaskExists: false);
    expect(item.status, 'waiting');
    expect(item.nativeQueued, isFalse);
    expect(item.autoQueue, isTrue);
  });

  test('orphaned running job is not silently restarted', () {
    final item = restored(status: 'running');
    TransferPolicy.reconcileRestoredDirect(item, nativeTaskExists: false);
    expect(item.status, 'error');
    expect(item.error, 'nativeMissing');
    expect(item.autoQueue, isFalse);
    expect(item.nativeQueued, isFalse);
  });

  test('missing previously queued native task requires explicit retry', () {
    final item = restored(status: 'waiting', nativeQueued: true);
    TransferPolicy.reconcileRestoredDirect(item, nativeTaskExists: false);
    expect(item.status, 'error');
    expect(item.error, 'nativeMissing');
    expect(item.autoQueue, isFalse);
  });

  test('local waiting and paused jobs are unchanged without native task', () {
    for (final status in ['waiting', 'paused']) {
      final item = restored(status: status, autoQueue: status == 'waiting');
      TransferPolicy.reconcileRestoredDirect(item, nativeTaskExists: false);
      expect(item.status, status);
      expect(item.nativeQueued, isFalse);
      expect(item.autoQueue, status == 'waiting');
      expect(item.retryAt, 456);
      expect(item.scheduledAt, 123);
    }
  });

  test('interrupted verification with native task awaits file verification', () {
    final item = restored(status: 'verifying', autoQueue: true);
    TransferPolicy.reconcileRestoredDirect(item, nativeTaskExists: true);
    expect(item.status, 'verifying');
    expect(item.nativeQueued, isTrue);
    expect(item.autoQueue, isFalse);
    expect(item.error, isEmpty);
  });

  test('orphaned verification fails closed rather than remaining stuck', () {
    final item = restored(status: 'verifying', nativeQueued: true);
    TransferPolicy.reconcileRestoredDirect(item, nativeTaskExists: false);
    expect(item.status, 'error');
    expect(item.error, 'verificationFailed');
    expect(item.nativeQueued, isFalse);
    expect(item.autoQueue, isFalse);
    // Reconciliation must never restart an unverified partial transfer.
    TransferPolicy.reconcileRestoredDirect(item, nativeTaskExists: false);
    expect(item.status, 'error');
    expect(item.autoQueue, isFalse);
  });

  test('interrupted verification of media or scheduled job is untouched', () {
    final cases = [
      restored(kind: 'video', status: 'verifying'),
      restored(status: 'verifying', scheduledExternally: true),
    ];
    for (final item in cases) {
      final before = item.toJson();
      TransferPolicy.reconcileRestoredDirect(item, nativeTaskExists: false);
      expect(item.toJson(), before);
    }
  });

  test('scheduled, media and terminal jobs remain untouched', () {
    final cases = [
      restored(status: 'waiting', scheduledExternally: true),
      restored(kind: 'video', status: 'running'),
      restored(status: 'complete'),
      restored(status: 'canceled'),
      restored(status: 'error'),
    ];
    for (final item in cases) {
      final before = item.toJson();
      TransferPolicy.reconcileRestoredDirect(item, nativeTaskExists: true);
      expect(item.toJson(), before, reason: '${item.kind}/${item.status}');
    }
  });
}
