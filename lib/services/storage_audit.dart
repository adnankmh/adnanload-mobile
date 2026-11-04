import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../models/download_entry.dart';

/// Scans only files referenced by ADNANLOAD history. Read-only by default.
class StorageAudit {
  /// Symlink resolution alone does not collapse hard links: different paths
  /// may still identify the same physical file. Compare identity only within
  /// equal-size buckets to avoid unnecessary filesystem checks.
  static Future<bool> _samePhysicalFileAlreadySeen(
    String canonicalPath,
    int size,
    Map<int, List<String>> seenBySize,
  ) async {
    for (final previous in seenBySize[size] ?? const <String>[]) {
      if (await FileSystemEntity.identical(previous, canonicalPath)) {
        return true;
      }
    }
    return false;
  }

  /// Compare distinct, stable on-disk files only. A download can still be
  /// writing (or a symlink can be retargeted) while this read-only audit runs.
  /// The optional digest callback makes these races deterministic in tests.
  static Future<List<List<DownloadEntry>>> findDuplicates(
    List<DownloadEntry> entries, {
    Future<String> Function(File)? hashFile,
  }) async {
    final lengths = <int, List<DownloadEntry>>{};
    final canonicalPaths = <DownloadEntry, String>{};
    // Multiple history records can reference the same downloaded file.
    // A duplicate must represent a second, distinct file on disk.
    final visitedPaths = <String>{};
    final physicalPathsBySize = <int, List<String>>{};
    for (final item in entries) {
      if (item.status != 'complete' || item.isPlaylist || item.path.isEmpty) {
        continue;
      }
      final file = File(item.path);
      try {
        final stat = await file.stat();
        if (stat.type != FileSystemEntityType.file || stat.size <= 0) continue;
        final canonicalPath = await file.resolveSymbolicLinks();
        if (visitedPaths.contains(canonicalPath) ||
            await _samePhysicalFileAlreadySeen(
                canonicalPath, stat.size, physicalPathsBySize)) {
          continue;
        }
        visitedPaths.add(canonicalPath);
        (physicalPathsBySize[stat.size] ??= <String>[]).add(canonicalPath);
        canonicalPaths[item] = canonicalPath;
        (lengths[stat.size] ??= <DownloadEntry>[]).add(item);
      } on FileSystemException {
        // Inaccessible or removed files are not duplicate candidates.
      }
    }

    final digestGroups = <String, List<DownloadEntry>>{};
    for (final sizeGroup in lengths.entries.where((x) => x.value.length > 1)) {
      for (final item in sizeGroup.value) {
        final file = File(item.path);
        try {
          // The file must still be the one observed during the size scan.
          final canonicalBefore = await file.resolveSymbolicLinks();
          if (canonicalBefore != canonicalPaths[item]) continue;
          final before = await file.stat();
          if (before.type != FileSystemEntityType.file ||
              before.size != sizeGroup.key) {
            continue;
          }
          final digest = hashFile == null
              ? (await sha256.bind(file.openRead()).first).toString()
              : await hashFile(file);
          final after = await file.stat();
          final canonicalAfter = await file.resolveSymbolicLinks();
          // Never classify a file from a stale or mixed digest. This catches
          // truncation, replacement, metadata changes and symlink retargeting.
          if (after.type != FileSystemEntityType.file ||
              after.size != before.size ||
              after.modified != before.modified ||
              after.changed != before.changed ||
              canonicalAfter != canonicalBefore) {
            continue;
          }
          (digestGroups[digest] ??= <DownloadEntry>[]).add(item);
        } on FileSystemException {
          // A file may disappear while its digest is being read.
        }
      }
    }
    return digestGroups.values.where((x) => x.length > 1).toList();
  }

  /// App-managed completed files only; cached downloads not in history are not counted.
  static Future<int> recordedBytes(List<DownloadEntry> entries) async {
    var total = 0;
    final visitedPaths = <String>{};
    final physicalPathsBySize = <int, List<String>>{};
    for (final entry in entries) {
      if (entry.status != 'complete' || entry.path.isEmpty || entry.isPlaylist) {
        continue;
      }
      try {
        final file = File(entry.path);
        final stat = await file.stat();
        if (stat.type != FileSystemEntityType.file) continue;
        // Normalize symlink/path aliases and avoid counting hard links twice.
        final canonicalPath = await file.resolveSymbolicLinks();
        if (visitedPaths.contains(canonicalPath) ||
            await _samePhysicalFileAlreadySeen(
                canonicalPath, stat.size, physicalPathsBySize)) {
          continue;
        }
        visitedPaths.add(canonicalPath);
        (physicalPathsBySize[stat.size] ??= <String>[]).add(canonicalPath);
        total += stat.size;
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
