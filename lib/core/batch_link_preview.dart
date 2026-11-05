import 'smart_link.dart';
import 'url_guard.dart';

/// Offline, conservative preview of a link before it enters the queue.
///
/// The server may supply a different filename or MIME type. This never
/// performs a network request or claims to know the remote file size.
class BatchLinkPreview {
  final String url;
  final String host;
  final String kind;
  final bool isPlaylist;
  final String? suggestedName;

  const BatchLinkPreview({
    required this.url,
    required this.host,
    required this.kind,
    required this.isPlaylist,
    required this.suggestedName,
  });

  factory BatchLinkPreview.fromUrl(String url, {String preferred = 'auto'}) {
    final uri = UrlGuard.validate(url);
    if (uri == null) {
      throw const FormatException('Only public HTTP(S) links are supported');
    }
    final detected = SmartLink.kind(url, preferred: preferred);
    final playlist = detected == 'playlist';
    final kind = playlist ? 'video' : detected;
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    // A page URL, or a file without a recognizable extension, cannot give
    // us a reliable filename until the server responds. Common web document
    // and server-script suffixes are not reliable download filenames.
    // Uri.pathSegments decodes escapes, so an encoded slash/backslash may
    // conceal multiple path components inside the apparent last segment.
    final pageLike = RegExp(
      r'\.(?:html?|xhtml|php\d?|aspx?|jspx?)
    return BatchLinkPreview(
      url: url,
      host: uri.host,
      kind: kind,
      isPlaylist: playlist,
      suggestedName: fileLike ? UrlGuard.safeName(last) : null,
    );
  }
}
,
      caseSensitive: false,
    ).hasMatch(last);
    final hasEncodedSeparator = last.contains('/') || last.contains('\\');
    final fileLike = kind == 'direct' &&
        !pageLike &&
        !hasEncodedSeparator &&
        RegExp(r'\.[a-zA-Z0-9]{1,16}
    return BatchLinkPreview(
      url: url,
      host: uri.host,
      kind: kind,
      isPlaylist: playlist,
      suggestedName: fileLike ? UrlGuard.safeName(last) : null,
    );
  }
}
).hasMatch(last);
    return BatchLinkPreview(
      url: url,
      host: uri.host,
      kind: kind,
      isPlaylist: playlist,
      suggestedName: fileLike ? UrlGuard.safeName(last) : null,
    );
  }
}
