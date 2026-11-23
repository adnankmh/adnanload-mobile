import 'package:yt_extractor/yt_extractor.dart';
import '../core/url_guard.dart';

class PlaylistPreviewEntry {
  final int index;
  final String title;
  final String imageUrl;
  const PlaylistPreviewEntry(this.index, this.title, this.imageUrl);
}

class PlaylistPreview {
  final String title;
  final List<PlaylistPreviewEntry> entries;
  const PlaylistPreview(this.title, this.entries);
}

/// Public playlist metadata only. This cannot access private or DRM media.
/// A capped and disposable native session prevents unbounded pagination.
class PlaylistExplorer {
  /// Keep previews bounded even when a caller supplies an excessive limit.
  /// Zero/negative limits previously returned an unintended first entry.
  static int boundedLimit(int requested) {
    if (requested < 1) {
      throw RangeError.range(requested, 1, 100, 'limit');
    }
    return requested > 100 ? 100 : requested;
  }

  /// Remote playlist metadata is untrusted. Never fetch non-HTTPS or
  /// local/private thumbnail URLs in the device's image widget.
  /// Preserve the original query string, including signed CDN parameters.
  static String safeThumbnailUrl(String? raw) {
    if (raw == null) return '';
    final candidate = raw.trim();
    final uri = UrlGuard.validate(candidate);
    if (uri == null || uri.scheme != 'https') return '';
    return candidate;
  }

  static Future<PlaylistPreview> inspect(String raw, {int limit = 100}) async {
    final maxItems = boundedLimit(limit);
    final url = UrlGuard.validate(raw);
    if (url == null) throw const FormatException('Invalid playlist URL');
    final service = YtExtractor(timeout: const Duration(seconds: 75));
    final page = await service.getPlaylist(url.toString());
    final entries = <PlaylistPreviewEntry>[];
    dynamic current = page;
    try {
      for (var iteration = 0; iteration < 10; iteration++) {
        for (final dynamic entry in current.items) {
          entries.add(PlaylistPreviewEntry(entries.length + 1,
            entry.name, safeThumbnailUrl(entry.thumbnailUrl)));
          if (entries.length >= maxItems) break;
        }
        if (entries.length >= maxItems || !current.hasNext) break;
        current = await service.loadMore(current.sessionId);
      }
      return PlaylistPreview(page.name, entries);
    } finally {
      // Page sessions are owned by the native extractor; do not retain them.
      try {await service.dispose(current.sessionId);} catch (_) {/* expired session */}
    }
  }
}
