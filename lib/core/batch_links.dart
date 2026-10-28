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
      final canonical = uri.replace(fragment: '').toString();
      if (seen.add(canonical)) {
        result.add(canonical);
        if (result.length >= maxLinks) break;
      }
    }
    return result;
  }
}
