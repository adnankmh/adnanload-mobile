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
  static Future<PlaylistPreview> inspect(String raw, {int limit = 100}) async {
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
            entry.name, entry.thumbnailUrl ?? ''));
          if (entries.length >= limit) break;
        }
        if (entries.length >= limit || !current.hasNext) break;
        current = await service.loadMore(current.sessionId);
      }
      return PlaylistPreview(page.name, entries);
    } finally {
      // Page sessions are owned by the native extractor; do not retain them.
      try {await service.dispose(current.sessionId);} catch (_) {/* expired session */}
    }
  }
}
