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


  /// Compare ASCII and Arabic-script decimal digit runs by numeric value
  /// without parsing integers. Very long episode numbers and mixed numeral
  /// scripts remain safe; equal values use the existing date/id tie-breaker.
  static int _compareNaturalName(String left, String right) {
    final a = left.toLowerCase();
    final b = right.toLowerCase();
    var i = 0;
    var j = 0;
    while (i < a.length && j < b.length) {
      final aDigit = _digitValue(a.codeUnitAt(i));
      final bDigit = _digitValue(b.codeUnitAt(j));
      if (aDigit != null && bDigit != null) {
        var aEnd = i;
        var bEnd = j;
        while (aEnd < a.length && _digitValue(a.codeUnitAt(aEnd)) != null) {
          aEnd++;
        }
        while (bEnd < b.length && _digitValue(b.codeUnitAt(bEnd)) != null) {
          bEnd++;
        }
        var aStart = i;
        var bStart = j;
        while (aStart < aEnd && _digitValue(a.codeUnitAt(aStart)) == 0) {
          aStart++;
        }
        while (bStart < bEnd && _digitValue(b.codeUnitAt(bStart)) == 0) {
          bStart++;
        }
        final aDigits = aEnd - aStart;
        final bDigits = bEnd - bStart;
        if (aDigits != bDigits) return aDigits.compareTo(bDigits);
        for (var k = 0; k < aDigits; k++) {
          final difference = _digitValue(a.codeUnitAt(aStart + k))!
              .compareTo(_digitValue(b.codeUnitAt(bStart + k))!);
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

  // Arabic-Indic (٠-٩) and Eastern Arabic-Indic (۰-۹) numerals are
  // common in Arabic download filenames. Treat them as decimal digits
  // alongside ASCII without parsing an unbounded integer or changing names.
  static int? _digitValue(int unit) {
    if (unit >= 0x30 && unit <= 0x39) return unit - 0x30;
    if (unit >= 0x0660 && unit <= 0x0669) return unit - 0x0660;
    if (unit >= 0x06F0 && unit <= 0x06F9) return unit - 0x06F0;
    return null;
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
