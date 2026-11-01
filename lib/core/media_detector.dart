import 'dart:convert';
import 'url_guard.dart';
import 'smart_link.dart';

/// Only explicitly exposed DOM URL candidates. No DRM decryption, credential
/// interception, cross-origin network sniffing or hidden stream capture.
class MediaDetector {
  static const domProbe = r'''(function(){
    const found = new Set();
    const add = (value) => {
      if (!value || found.size >= 12) return;
      try { const u = new URL(value, document.baseURI);
        if (u.protocol === 'https:' || u.protocol === 'http:') found.add(u.href);
      } catch (_) {}
    };
    document.querySelectorAll('video[src],video source[src],audio[src],audio source[src],a[download]')
      .forEach(el => add(el.currentSrc || el.src || el.href));
    document.querySelectorAll('meta[property="og:video"],meta[property="og:audio"]')
      .forEach(el => add(el.content));
    return JSON.stringify(Array.from(found));
  })()''';

  /// Direct media files use the resumable native downloader, while stream
  /// manifests and known media pages use the extractor. No DRM interception.
  static String detectedDownloadKind(String url) {
    final uri = UrlGuard.validate(url);
    if (uri == null) return 'direct';
    if (RegExp(r'\.(m3u8|mpd)$', caseSensitive: false).hasMatch(uri.path)) {
      return 'video';
    }
    return SmartLink.incomingKind(url);
  }

  static List<String> parse(Object? value) {
    dynamic parsed = value;
    try {
      if(parsed is String) parsed=jsonDecode(parsed);
      if(parsed is String) parsed=jsonDecode(parsed);
    } catch (_) {return const [];} 
    if(parsed is! List) return const [];
    final urls = <String>[];
    for(final item in parsed) {
      if (item is! String || item.length > 2048) continue;
      final uri=UrlGuard.validate(item);
      if (uri==null) continue;
      final url=uri.toString();
      if (!urls.contains(url)) urls.add(url);
      if (urls.length>=12)break;
    }
    return urls;
  }
}
