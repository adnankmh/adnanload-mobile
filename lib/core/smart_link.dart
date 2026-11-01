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

  static String category(String filename) {
    final n = filename.toLowerCase().split('?').first;
    if (RegExp(r'\.(mp4|mkv|mov|avi|webm|m4v)$').hasMatch(n)) return 'video';
    if (RegExp(r'\.(mp3|m4a|wav|flac|ogg|opus|aac)$').hasMatch(n)) return 'audio';
    if (RegExp(r'\.(pdf|txt|docx?|xlsx?|pptx?|csv|epub|rtf)$').hasMatch(n)) return 'document';
    if (RegExp(r'\.(apk|exe|msi|deb|rpm|dmg)$').hasMatch(n)) return 'application';
    if (RegExp(r'\.(zip|7z|rar|tar|gz)$').hasMatch(n)) return 'archive';
    if (RegExp(r'\.(jpe?g|png|gif|webp|bmp|svg)$').hasMatch(n)) return 'image';
    return 'file';
  }
}
