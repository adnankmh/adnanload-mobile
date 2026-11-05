import '../models/download_entry.dart';

/// View-only sorting for the Downloads screen. Never changes queue order,
/// persisted history, native task priority or scheduling.
class DownloadListSort {
  static const modes = <String>['newest', 'oldest', 'name', 'priority'];

  static List<DownloadEntry> ordered(
      Iterable<DownloadEntry> source, String mode) {
    final entries = source.toList();
    entries.sort((a, b) {
      final comparison = switch (mode) {
        'oldest' => a.addedAt.compareTo(b.addedAt),
        'name' => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        // Smaller numbers dispatch first in DownloadRepository._pump.
        'priority' => a.priority.compareTo(b.priority),
        _ => b.addedAt.compareTo(a.addedAt),
      };
      if (comparison != 0) return comparison;
      // Deterministic ties keep rows from jumping between rebuilds.
      final byDate = b.addedAt.compareTo(a.addedAt);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
    return entries;
  }

  static String label(String mode, {required bool arabic}) {
    if (arabic) {
      return switch (mode) {
        'oldest' => 'الأقدم أولاً',
        'name' => 'حسب الاسم',
        'priority' => 'حسب أولوية الطابور',
        _ => 'الأحدث أولاً',
      };
    }
    return switch (mode) {
      'oldest' => 'Oldest first',
      'name' => 'Name',
      'priority' => 'Queue priority',
      _ => 'Newest first',
    };
  }
}
