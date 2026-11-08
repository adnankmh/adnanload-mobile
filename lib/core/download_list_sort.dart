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
        'name' => _compareNaturalName(a.name, b.name),
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


  /// Compare ASCII digit runs by their numeric value without parsing integers.
  /// This handles very long episode/part numbers and ignores leading zeros;
  /// equal numeric names still use the existing date/id tie-breaker.
  static int _compareNaturalName(String left, String right) {
    final a = left.toLowerCase();
    final b = right.toLowerCase();
    var i = 0;
    var j = 0;
    while (i < a.length && j < b.length) {
      final aDigit = _isAsciiDigit(a.codeUnitAt(i));
      final bDigit = _isAsciiDigit(b.codeUnitAt(j));
      if (aDigit && bDigit) {
        var aEnd = i;
        var bEnd = j;
        while (aEnd < a.length && _isAsciiDigit(a.codeUnitAt(aEnd))) {
          aEnd++;
        }
        while (bEnd < b.length && _isAsciiDigit(b.codeUnitAt(bEnd))) {
          bEnd++;
        }
        var aStart = i;
        var bStart = j;
        while (aStart < aEnd && a.codeUnitAt(aStart) == 48) {
          aStart++;
        }
        while (bStart < bEnd && b.codeUnitAt(bStart) == 48) {
          bStart++;
        }
        final aDigits = aEnd - aStart;
        final bDigits = bEnd - bStart;
        if (aDigits != bDigits) return aDigits.compareTo(bDigits);
        for (var k = 0; k < aDigits; k++) {
          final difference = a.codeUnitAt(aStart + k)
              .compareTo(b.codeUnitAt(bStart + k));
          if (difference != 0) return difference;
        }
        i = aEnd;
        j = bEnd;
        continue;
      }
      final difference = a.codeUnitAt(i).compareTo(b.codeUnitAt(j));
      if (difference != 0) return difference;
      i++;
      j++;
    }
    return (a.length - i).compareTo(b.length - j);
  }

  static bool _isAsciiDigit(int unit) => unit >= 48 && unit <= 57;

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
