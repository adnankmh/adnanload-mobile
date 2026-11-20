import '../models/download_entry.dart';
import 'filename_search.dart';
import 'smart_link.dart';

/// Matches completed downloads in the Files tab without relying solely on
/// the user-facing title, which may not contain a file extension.
class FileHubFilter {
  static String category(DownloadEntry entry) {
    // The stored file is authoritative when its basename has a known type.
    // SAF/opaque destinations may not have an extension, so use the title then.
    final actual = SmartLink.category(_storedBasename(entry.path));
    if (actual != 'file') return actual;
    return SmartLink.category(_basename(entry.name));
  }

  static bool matches(
    DownloadEntry entry, {
    required String selected,
    String query = '',
  }) {
    final type = category(entry);
    final categoryMatches = switch (selected) {
      'videoFiles' => type == 'video',
      'audioFiles' => type == 'audio',
      'documentFiles' => type == 'document',
      'otherFiles' => type != 'video' && type != 'audio' && type != 'document',
      _ => true,
    };
    if (!categoryMatches) return false;

    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    // Search only display and stored basenames, never parent directories.
    // Apply the same Arabic folding as the Downloads tab.
    return FilenameSearch.contains(entry.name, needle) ||
        FilenameSearch.contains(_storedBasename(entry.path), needle);
  }

  // SAF document IDs may encode a volume and nested directories in one
  // URI segment. Decode that segment once, then keep only the filename.
  // Never search URI query/fragment metadata or parent directory names.
  static String _storedBasename(String path) {
    if (!path.toLowerCase().startsWith('content://')) return _basename(path);
    try {
      final uri = Uri.parse(path);
      if (uri.pathSegments.isEmpty) return '';
      var name = uri.pathSegments.last;
      if (uri.host == 'com.android.externalstorage.documents') {
        final separator = name.indexOf(':');
        if (separator >= 0) name = name.substring(separator + 1);
      }
      return _basename(name);
    } on FormatException {
      return '';
    }
  }

  static String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.substring(normalized.lastIndexOf('/') + 1);
  }
}
