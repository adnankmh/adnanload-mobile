import '../models/download_entry.dart';
import 'filename_search.dart';

/// Keeps the Downloads tab's status chips consistent with the transfer
/// lifecycle. A transfer remains active while it is being submitted or
/// its completed bytes are being verified.
class DownloadListFilter {
  static const filters = <String>[
    'all', 'active', 'finished', 'failed', 'waiting', 'running',
    'paused', 'scheduled', 'retrying', 'verifying',
  ];

  static String label(String filter, {required bool arabic}) =>
      switch (filter) {
        'retrying' => arabic ? 'إعادة المحاولة' : 'Retrying',
        'verifying' => arabic ? 'التحقق من السلامة' : 'Verifying',
        _ => filter,
      };

  static bool matches(DownloadEntry item,
      {required String filter, required String query}) {
    final matchingStatus = switch (filter) {
      'active' => const {
          'running', 'waiting', 'paused', 'submitting', 'verifying'
        }.contains(item.status),
      'waiting' => item.status == 'waiting',
      'running' => item.status == 'running',
      'paused' => item.status == 'paused',
      'scheduled' => item.status == 'waiting' && item.scheduledAt > 0,
      'retrying' => item.status == 'waiting' && item.retryAt > 0,
      'verifying' => item.status == 'verifying',
      'finished' => item.status == 'complete',
      'failed' => const {'error', 'canceled'}.contains(item.status),
      _ => true,
    };
    if (!matchingStatus) return false;

    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    // Only the display filename is folded; signed URL text stays literal.
    return FilenameSearch.contains(item.name, needle) ||
        item.url.toLowerCase().contains(needle);
  }
}
