import '../models/download_entry.dart';

/// Aggregate-only download telemetry. Does not expose URLs or filenames.
class DownloadMetrics {
  final int completed;
  final int running;
  final int waiting;
  final int failed;
  final int total;
  final double currentMbPerSecond;
  final int retrying;
  const DownloadMetrics({required this.completed, required this.running,
    required this.waiting, required this.failed, required this.total,
    required this.currentMbPerSecond, required this.retrying});

  factory DownloadMetrics.fromEntries(Iterable<DownloadEntry> entries) {
    var completed = 0, running = 0, waiting = 0, failed = 0, total = 0, retrying = 0;
    var speed = 0.0;
    for (final item in entries) {
      total++;
      if (item.status == 'complete') completed++;
      if (item.status == 'running') {
        running++;
        // Restored or native-reported rates may be stale, negative or
        // non-finite. Never let one bad rate corrupt the dashboard total.
        if (item.speed.isFinite && item.speed > 0) {
          final combined = speed + item.speed;
          speed = combined.isFinite ? combined : double.maxFinite;
        }
      }
      if (item.status == 'waiting' || item.status == 'submitting') waiting++;
      if (item.status == 'error') failed++;
      if (item.retryAt > 0 && item.status == 'waiting') retrying++;
    }
    return DownloadMetrics(completed: completed, running: running, waiting: waiting,
      failed: failed, total: total, currentMbPerSecond: speed, retrying: retrying);
  }
}
