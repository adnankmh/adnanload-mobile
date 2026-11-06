import '../models/download_entry.dart';

/// View-only sorting for the Downloads screen. Never changes queue order,
/// persisted history, native task priority or scheduling.
class DownloadListSort {
  static const modes = <String>['newest', 'oldest', 'name', 'priority', 'scheduled'];

  static List<DownloadEntry> ordered(
      Iterable<DownloadEntry> source, String mode) {
    final entries = source.toList();
    entries.sort((a, b) {
      final comparison = switch (mode) {
        'oldest' => a.addedAt.compareTo(b.addedAt),
        'name' => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        // Smaller numbers dispatch first in DownloadRepository._pump.
        'priority' => a.priority.compareTo(b.priority),
        // Pending scheduled jobs first, ordered by their requested start time.
        // Completed, canceled and unscheduled jobs retain newest-first order.
        'scheduled' => _compareScheduled(a, b),
        _ => b.addedAt.compareTo(a.addedAt),
      };
      if (comparison != 0) return comparison;
      // Deterministic ties keep rows from jumping between rebuilds.
      final byDate = b.addedAt.compareTo(a.addedAt);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
    return entries;
  }

  static int _compareScheduled(DownloadEntry a, DownloadEntry b) {
    final aTime = a.status == 'waiting' && a.scheduledAt > 0
        ? a.scheduledAt : null;
    final bTime = b.status == 'waiting' && b.scheduledAt > 0
        ? b.scheduledAt : null;
    if (aTime == null) return bTime == null ? 0 : 1;
    if (bTime == null) return -1;
    return aTime.compareTo(bTime);
  }

  static String label(String mode, {required bool arabic}) {
    if (arabic) {
      return switch (mode) {
        'oldest' => 'الأقدم أولاً',
        'name' => 'حسب الاسم',
        'priority' => 'حسب أولوية الطابور',
        'scheduled' => 'المجدولة الأقرب أولاً',
        _ => 'الأحدث أولاً',
      };
    }
    return switch (mode) {
      'oldest' => 'Oldest first',
      'name' => 'Name',
      'priority' => 'Queue priority',
      'scheduled' => 'Next scheduled',
      _ => 'Newest first',
    };
  }
}
