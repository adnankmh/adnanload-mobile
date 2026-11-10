import 'playlist_rules.dart';
import 'url_guard.dart';

/// Conservative route selection. File URLs go straight to Android's native
/// downloader; pages from supported media sites use the extractor.
class SmartLink {
  static String kind(String url, {String preferred = 'auto'}) {
    final uri = UrlGuard.validate(url);
    if (uri == null) return 'direct';
    if (PlaylistRules.looksLikePlaylist(url)) return 'playlist';
    final path = uri.path.toLowerCase();
    if (RegExp(r'\.(mp4|mkv|mov|avi|webm|mp3|wav|flac|m4a|opus|ogg|pdf|zip|rar|7z|apk|exe|msi|tar|gz|txt|csv|docx?|xlsx?|pptx?|epub|iso|png|jpe?g|gif|webp)$').hasMatch(path)) {
      return 'direct';
    }
    if (preferred == 'mp3' || preferred == 'video' || preferred == 'direct') return preferred;
    return PlaylistRules.looksLikeMediaSite(url) ? 'video' : 'direct';
  }

  /// Route known media webpages through extraction instead of downloading HTML.
  /// Explicit media choices (video/audio) remain unchanged.
  static String incomingKind(String url, {String requested = 'direct'}) {
    if (requested != 'direct') return requested;
    final detected = kind(url);
    return detected == 'playlist' ? 'video' : detected;
  }

  /// Classify both URL-style names (with query/fragment) and literal names.
  ///
  /// Application packages take precedence in either interpretation. This is
  /// deliberately conservative because callers use this category to suppress
  /// automatic opening of downloaded installers.
  static String category(String filename) {
    final full = filename.toLowerCase();
    final withoutUrlSuffix = full.split(RegExp(r'[?#]')).first;
    final baseCategory = _categoryByExtension(withoutUrlSuffix);
    final literalCategory = _categoryByExtension(full);
    if (baseCategory == 'application' || literalCategory == 'application') {
      return 'application';
    }
    return baseCategory == 'file' ? literalCategory : baseCategory;
  }

  static String _categoryByExtension(String name) {
    if (RegExp(r'\.(mp4|mkv|mov|avi|webm|m4v)$').hasMatch(name)) return 'video';
    if (RegExp(r'\.(mp3|m4a|wav|flac|ogg|opus|aac)$').hasMatch(name)) return 'audio';
    if (RegExp(r'\.(pdf|txt|docx?|xlsx?|pptx?|csv|epub|rtf)$').hasMatch(name)) return 'document';
    if (RegExp(r'\.(apk|apks|xapk|aab|exe|msi|deb|rpm|dmg)$').hasMatch(name)) return 'application';
    if (RegExp(r'\.(zip|7z|rar|tar|gz)$').hasMatch(name)) return 'archive';
    if (RegExp(r'\.(jpe?g|png|gif|webp|bmp|svg)$').hasMatch(name)) return 'image';
    return 'file';
  }
}
