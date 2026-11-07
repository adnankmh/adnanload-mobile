import '../models/download_entry.dart';

/// Keeps the Downloads tab's status chips consistent with the transfer
/// lifecycle. A transfer remains active while it is being submitted or
/// its completed bytes are being verified.
class DownloadListFilter {
  static bool matches(DownloadEntry item,
      {required String filter, required String query}) {
    final matchingStatus = switch (filter) {
      'active' => const {
          'running', 'waiting', 'paused', 'submitting', 'verifying'
        }.contains(item.status),
      'finished' => item.status == 'complete',
      'failed' => const {'error', 'canceled'}.contains(item.status),
      _ => true,
    };
    if (!matchingStatus) return false;

    final needle = query.trim().toLowerCase();
    return needle.isEmpty ||
        item.name.toLowerCase().contains(needle) ||
        item.url.toLowerCase().contains(needle);
  }
}
