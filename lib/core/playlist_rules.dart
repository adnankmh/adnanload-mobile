/// Sanitizes the yt-dlp --playlist-items expression, never a shell command.
/// Empty means the complete list. Supports 1,3-9,12 and 1:30.
class PlaylistRules {
  static final RegExp _allowed = RegExp(r'^[0-9,:\- ]{1,200}$');

  static String parseItems(String raw) {
    final text = raw.trim().replaceAll(' ', '');
    if (text.isEmpty) return '';
    if (!_allowed.hasMatch(text) ||
        !RegExp(r'^(?:[1-9]\d*(?:[-:][1-9]\d*)?)(?:,(?:[1-9]\d*(?:[-:][1-9]\d*)?))*$').hasMatch(text)) {
      throw const FormatException('Invalid playlist range');
    }
    for (final part in text.split(',')) {
      final range = part.split(RegExp(r'[-:]'));
      if (range.length == 2 && int.parse(range.first) > int.parse(range.last)) {
        throw const FormatException('Descending playlist range');
      }
    }
    return text;
  }

  static bool looksLikePlaylist(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    if (host == 'youtube.com' || host.endsWith('.youtube.com')) {
      // A bare /playlist page or an empty/ambiguous list parameter is not
      // a playlist. Do not route it into playlist expansion/extraction.
      final ids = uri.queryParametersAll['list'];
      final hasPlaylistId =
          ids != null && ids.length == 1 && ids.single.trim().isNotEmpty;
      return hasPlaylistId &&
          (path.startsWith('/playlist') || !path.startsWith('/watch'));
    }
    // Preserve playlist-style routes on other media services.
    // SoundCloud artist sets use /<artist>/sets/<slug>, not /sets/<slug>.
    // Keep other providers' existing routing unchanged.
    final isSoundCloud =
        host == 'soundcloud.com' || host.endsWith('.soundcloud.com');
    final artistSet = isSoundCloud && RegExp(r'/sets/[^/]+').hasMatch(path);
    return path.contains('/playlist/') || path.startsWith('/sets/') ||
        artistSet || path.contains('/collections/');
  }

  static bool looksLikeMediaSite(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    const supportedHints = <String>[
      'youtube.com','youtu.be','instagram.com','facebook.com','fb.watch',
      'tiktok.com','x.com','twitter.com','vimeo.com','dailymotion.com',
      'twitch.tv','reddit.com','soundcloud.com','bandcamp.com',
      'bilibili.com','pinterest.com','threads.net',
    ];
    return supportedHints.any((hint) => host == hint || host.endsWith('.$hint'));
  }
}
