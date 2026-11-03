import 'dart:async';

import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:adnanload_mobile/models/download_entry.dart';
import 'package:flutter_test/flutter_test.dart';

DownloadEntry directJob({
  String kind = 'direct',
  String status = 'submitting',
  bool nativeQueued = false,
  bool scheduledExternally = false,
}) => DownloadEntry(
  id: 'cancel-race',
  url: 'https://example.org/archive.zip',
  name: 'archive.zip',
  kind: kind,
  status: status,
  addedAt: 1,
  autoQueue: true,
  nativeQueued: nativeQueued,
  scheduledExternally: scheduledExternally,
  retryAt: 12345,
);

bool allowed(DownloadEntry item, {bool tracked = true}) =>
    TransferPolicy.directSubmissionStillAllowed(item, isTracked: tracked);

void main() {
  test('only a tracked, actively submitting direct job may enqueue', () {
    final item = directJob();
    expect(allowed(item), isTrue);
    expect(allowed(item, tracked: false), isFalse);
    for (final state in ['waiting', 'paused', 'canceled', 'error', 'complete']) {
      item.status = state;
      expect(allowed(item), isFalse, reason: state);
    }
  });

  test('a native or externally scheduled job cannot be submitted twice', () {
    expect(allowed(directJob(nativeQueued: true)), isFalse);
    expect(allowed(directJob(scheduledExternally: true)), isFalse);
    expect(allowed(directJob(kind: 'video')), isFalse);
  });

  test('cancel revokes submission synchronously before platform cleanup', () {
    final item = directJob();
    expect(allowed(item), isTrue);
    TransferPolicy.markCanceled(item);
    expect(item.status, 'canceled');
    expect(item.autoQueue, isFalse);
    expect(item.nativeQueued, isFalse);
    expect(item.retryAt, 0);
    expect(allowed(item), isFalse);
  });

  test('cancel during a pending preflight invalidates its later result', () async {
    final item = directJob();
    final gate = Completer<void>();
    final pendingPreflight = () async {
      await gate.future;
      return allowed(item);
    }();
    TransferPolicy.markCanceled(item);
    gate.complete();
    expect(await pendingPreflight, isFalse);
  });

  test('cancel after native task registration remains terminal', () {
    final item = directJob(nativeQueued: true, status: 'running');
    TransferPolicy.markCanceled(item);
    expect(item.status, 'canceled');
    expect(item.nativeQueued, isFalse);
    expect(allowed(item), isFalse);
    // A repeated cancel must not re-enable auto-queue or native state.
    TransferPolicy.markCanceled(item);
    expect(item.status, 'canceled');
    expect(item.autoQueue, isFalse);
  });
}
