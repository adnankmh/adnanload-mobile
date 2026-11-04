import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../core/url_guard.dart';
import '../models/download_entry.dart';

/// Portable backup includes public URLs, history, bookmarks and preferences.
/// It intentionally excludes credentials, cookies, app PIN and downloaded bytes.
class BackupService {
  static const schema = 1;

  /// Backups are portable history, not a copy of device-local transfer state.
  /// In particular, native paths and error messages may contain private
  /// filesystem locations or temporary access details. Import already resets
  /// these fields; do not write them into the exported JSON in the first place.
  /// Keep the original URL and expected checksum so the user can restore jobs.
  static Map<String, dynamic> _exportEntry(DownloadEntry entry) => {
    ...entry.toJson(),
    'path': '',
    'error': '',
    'actualSha256': '',
    'autoQueue': false,
    'nativeQueued': false,
    'scheduledExternally': false,
    'scheduledAt': 0,
    'retryAttempts': 0,
    'retryAt': 0,
  };

  static Map<String,dynamic> create({required List<DownloadEntry> items,
      required List<String> bookmarks, required String theme,
      required String language, required bool wifiOnly}) => {
    'application': 'ADNANLOAD', 'schema': schema,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'preferences': {'theme': theme, 'language': language, 'wifiOnly': wifiOnly},
    'bookmarks': bookmarks.take(150).toList(),
    'history': items.take(350).map(_exportEntry).toList(),
  };

  static Future<String> writeBackup(Map<String,dynamic> data) async {
    final temp = await getTemporaryDirectory();
    final folder = Directory('${temp.path}${Platform.pathSeparator}ADNANLOAD-temp');
    await folder.create(recursive:true);
    final path = '${folder.path}${Platform.pathSeparator}adnanload-backup-${DateTime.now().millisecondsSinceEpoch}.json';
    await File(path).writeAsString(jsonEncode(data), flush: true);
    return path;
  }

  static Map<String,dynamic> parse(String text) {
    if (text.length > 5 * 1024 * 1024) throw const FormatException('Backup too large');
    final decoded = jsonDecode(text);
    if (decoded is! Map<String,dynamic> || decoded['application'] != 'ADNANLOAD' || decoded['schema'] != schema ||
        decoded['history'] is! List || decoded['bookmarks'] is! List || decoded['preferences'] is! Map) {
      throw const FormatException('Invalid or unsupported backup');
    }
    if ((decoded['history'] as List).length > 350 || (decoded['bookmarks'] as List).length > 150) {
      throw const FormatException('Backup exceeds safety limits');
    }
    return decoded;
  }

  static List<DownloadEntry> validEntries(Map<String,dynamic> backup) {
    final entries = <DownloadEntry>[];
    var ordinal = 0;
    for (final value in backup['history'] as List) {
      if (value is! Map<String,dynamic>) continue;
      try {
        final raw=DownloadEntry.fromJson(value);
        if (UrlGuard.validate(raw.url) == null ||
            !const {'direct','video','mp3'}.contains(raw.kind)) continue;
        // Import gets fresh task IDs; never bind to an existing native task.
        final e = DownloadEntry.fromJson({...raw.toJson(),
          'id': 'import_${DateTime.now().microsecondsSinceEpoch}_${ordinal++}',
          'name':UrlGuard.safeName(raw.name)});
        // Never auto-run imported jobs, and never trust imported local file paths.
        e.autoQueue = false; e.nativeQueued = false; e.scheduledExternally = false; e.path = ''; e.actualSha256 = '';
        e.status = 'waiting'; e.progress = 0; e.speed = 0;
        e.error = ''; e.scheduledAt = 0; e.retryAttempts = 0; e.retryAt = 0;
        entries.add(e);
      } catch (_) { /* damaged entry ignored */ }
    }
    return entries;
  }
}
