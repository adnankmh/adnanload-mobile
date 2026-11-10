import '../models/download_entry.dart';

/// Keeps the Downloads tab's status chips consistent with the transfer
/// lifecycle. A transfer remains active while it is being submitted or
/// its completed bytes are being verified.
class DownloadListFilter {
  /// Fold common Arabic spelling/diacritic variants for *filename* search.
  /// Do not normalize the URL: its query may contain case-sensitive tokens
  /// or percent-encoded signatures that must retain literal search behavior.
  static String _foldArabicSearch(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي');

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
    if (needle.isEmpty) return true;
    final foldedNeedle = _foldArabicSearch(needle);
    return (foldedNeedle.isNotEmpty &&
            _foldArabicSearch(item.name).contains(foldedNeedle)) ||
        item.url.toLowerCase().contains(needle);
  }
}
