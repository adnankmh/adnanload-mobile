import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../models/download_entry.dart';

/// Scans only files referenced by ADNANLOAD history. Read-only by default.
class StorageAudit {
  static Future<List<List<DownloadEntry>>> findDuplicates(List<DownloadEntry> entries) async {
    final lengths = <int, List<DownloadEntry>>{};
    // Multiple history records can reference the same downloaded file.
    // A duplicate must represent a second, distinct file on disk.
    final visitedPaths = <String>{};
    for (final item in entries) {
      if (item.status != 'complete' || item.isPlaylist || item.path.isEmpty) continue;
      final file = File(item.path);
      try {
        if (!await file.exists()) continue;
        // Distinct history paths may resolve to the same file through '..'
        // segments or symlinks. Count the underlying file only once.
        final canonicalPath = await file.resolveSymbolicLinks();
        if (!visitedPaths.add(canonicalPath)) continue;
        final length = await file.length();
        // Empty files are not valid completed downloads.
        if (length == 0) continue;
        (lengths[length] ??= <DownloadEntry>[]).add(item);
      } on FileSystemException { /* inaccessible file: skip */ }
    }
    final digestGroups = <String,List<DownloadEntry>>{};
    for (final group in lengths.values.where((x) => x.length > 1)) {
      for (final item in group) {
        try {
          final hash = await sha256.bind(File(item.path).openRead()).first;
          (digestGroups[hash.toString()] ??= <DownloadEntry>[]).add(item);
        } on FileSystemException { /* inaccessible file: skip */ }
      }
    }
    return digestGroups.values.where((x) => x.length > 1).toList();
  }

  /// App-managed completed files only; cached downloads not in history are not counted.
  static Future<int> recordedBytes(List<DownloadEntry> entries) async {
    var total = 0;
    final visitedPaths = <String>{};
    for (final entry in entries) {
      if (entry.status != 'complete' || entry.path.isEmpty || entry.isPlaylist) {
        continue;
      }
      try {
        final file = File(entry.path);
        if (!await file.exists()) continue;
        // Normalize aliases before accounting for app-managed storage.
        final canonicalPath = await file.resolveSymbolicLinks();
        if (!visitedPaths.add(canonicalPath)) continue;
        total += await file.length();
      } on FileSystemException { /* file was removed or inaccessible */ }
    }
    return total;
  }

  /// Delete only app-owned temporary files older than 24h, never actual downloads.
  static Future<int> clearOldTemporaryFiles() async {
    final cache = await getTemporaryDirectory();
    final dir = Directory('${cache.path}${Platform.pathSeparator}ADNANLOAD-temp');
    if (!await dir.exists()) return 0;
    var removed = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      if (DateTime.now().difference(stat.modified) < const Duration(hours: 24)) continue;
      await entity.delete(); removed++;
    }
    return removed;
  }
}
