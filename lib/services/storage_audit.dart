import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../models/download_entry.dart';

/// Scans only files referenced by ADNANLOAD history. Read-only by default.
class StorageAudit {
  static Future<List<List<DownloadEntry>>> findDuplicates(List<DownloadEntry> entries) async {
    final lengths = <int, List<DownloadEntry>>{};
    for (final item in entries) {
      if (item.status != 'complete' || item.isPlaylist || item.path.isEmpty) continue;
      final f = File(item.path);
      try {
        if (await f.exists()) {
          final len = await f.length();
          (lengths[len] ??= <DownloadEntry>[]).add(item);
        }
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
    var total=0;
    final visited=<String>{};
    for(final entry in entries){
      if(entry.status!='complete' || entry.path.isEmpty || entry.isPlaylist)continue;
      if(!visited.add(entry.path))continue;
      try {final file=File(entry.path);if(await file.exists())total+=await file.length();}
      on FileSystemException { /* file was removed or inaccessible */ }
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
