import 'package:adnanload_mobile/core/download_metrics.dart';
import 'package:adnanload_mobile/models/download_entry.dart';
import 'package:flutter_test/flutter_test.dart';

DownloadEntry entry(String id, String status, double speed, {int retryAt = 0}) {
  return DownloadEntry(
    id: id,
    url: 'https://example.org/file.zip',
    name: 'file.zip',
    kind: 'direct',
    status: status,
    speed: speed,
    addedAt: 0,
    retryAt: retryAt,
  );
}

void main() {
  test('sums only valid positive rates from running transfers', () {
    final metrics = DownloadMetrics.fromEntries([
      entry('a', 'running', 2.5),
      entry('b', 'running', 1.25),
      entry('c', 'complete', 900),
      entry('d', 'paused', 300),
    ]);
    expect(metrics.running, 2);
    expect(metrics.completed, 1);
    expect(metrics.total, 4);
    expect(metrics.currentMbPerSecond, 3.75);
  });

  test('non-finite and negative native rates cannot poison dashboard', () {
    final metrics = DownloadMetrics.fromEntries([
      entry('a', 'running', double.nan),
      entry('b', 'running', double.infinity),
      entry('c', 'running', double.negativeInfinity),
      entry('d', 'running', -12),
      entry('e', 'running', 3.5),
      entry('f', 'waiting', 999, retryAt: 123),
      entry('g', 'error', 200),
    ]);
    expect(metrics.running, 5);
    expect(metrics.waiting, 1);
    expect(metrics.retrying, 1);
    expect(metrics.failed, 1);
    expect(metrics.currentMbPerSecond, 3.5);
  });

  test('extreme finite rates saturate instead of overflowing to infinity', () {
    final metrics = DownloadMetrics.fromEntries([
      entry('a', 'running', double.maxFinite),
      entry('b', 'running', double.maxFinite),
    ]);
    expect(metrics.currentMbPerSecond.isFinite, isTrue);
    expect(metrics.currentMbPerSecond, double.maxFinite);
  });

  test('no usable running rate displays zero', () {
    final metrics = DownloadMetrics.fromEntries([
      entry('a', 'running', double.nan),
      entry('b', 'complete', 50),
    ]);
    expect(metrics.currentMbPerSecond, 0);
    expect(metrics.running, 1);
  });
}
