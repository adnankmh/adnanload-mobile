import 'url_guard.dart';

/// Parse a list of public HTTP(S) links without silently accepting local URLs.
class BatchLinks {
  static const maxLinks = 100;
  static List<String> parse(String text, {Set<String> existing = const {}}) {
    final result = <String>[];
    // History entries may retain fragments (for example, a link imported
    // before the current batch parser). Normalize both sides of the comparison
    // so a fragment-only difference never queues the same resource again.
    final seen = <String>{};
    for (final url in existing) {
      final canonical = _canonical(url);
      if (canonical != null) seen.add(canonical);
    }
    for (final token in text.split(RegExp(r'[\s]+'))) {
      final cleaned = token.trim().replaceAll(RegExp(r'^[<"\x27]+|[>"\x27,;]+$'), '');
      if (cleaned.isEmpty) continue;
      final canonical = _canonical(cleaned);
      if (canonical == null) continue;
      if (seen.add(canonical)) {
        result.add(canonical);
        if (result.length >= maxLinks) break;
      }
    }
    return result;
  }

  /// Fragments are client-side anchors, not part of the HTTP resource.
  /// Retain query strings verbatim, including expiring signed parameters.
  static String? _canonical(String url) {
    final uri = UrlGuard.validate(url);
    if (uri == null) return null;
    final value = uri.toString();
    final fragment = value.indexOf('#');
    return fragment < 0 ? value : value.substring(0, fragment);
  }
}
