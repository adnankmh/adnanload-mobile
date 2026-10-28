import 'url_guard.dart';

/// Parse a list of public HTTP(S) links without silently accepting local URLs.
class BatchLinks {
  static const maxLinks = 100;
  static List<String> parse(String text, {Set<String> existing = const {}}) {
    final result = <String>[];
    final seen = <String>{...existing};
    for (final token in text.split(RegExp(r'[\s]+'))) {
      final cleaned = token.trim().replaceAll(RegExp(r'^[<"\x27]+|[>"\x27,;]+$'), '');
      if (cleaned.isEmpty) continue;
      final uri = UrlGuard.validate(cleaned);
      if (uri == null) continue;
      // Fragments do not affect resource retrieval; preserve query strings.
      final raw = uri.toString();
      final fragmentIndex = raw.indexOf('#');
      final canonical = fragmentIndex < 0 ? raw : raw.substring(0, fragmentIndex);
      if (seen.add(canonical)) {
        result.add(canonical);
        if (result.length >= maxLinks) break;
      }
    }
    return result;
  }
}
