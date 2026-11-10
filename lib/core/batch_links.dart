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
    // Markdown link labels may contain spaces. Extract only the URL from
    // simple [label](https://...) and ![alt](https://...) links before
    // splitting on whitespace. Keep query bytes (including signed commas and
    // semicolons) unchanged; UrlGuard still rejects unsafe destinations.
    // Bare URLs with literal parentheses are not modified by this pattern.
    // CommonMark also allows angle-wrapped destinations. Their brackets
    // disambiguate literal parentheses in file paths and signed queries.
    // Validate the extracted URL through the same UrlGuard as plain links.
    final angleMarkdownLinks = RegExp(
      r'!?\[[^\]\r\n]*\]\(<(https?://[^\s<>]+)>\)',
      caseSensitive: false,
    );
    final angleExpanded = text.replaceAllMapped(
      angleMarkdownLinks, (match) => ' ${match.group(1)} ',
    );
    final markdownLinks = RegExp(
      r'!?\[[^\]\r\n]*\]\((https?://[^\s()]+)\)',
      caseSensitive: false,
    );
    final expanded = angleExpanded.replaceAllMapped(
      markdownLinks, (match) => ' ${match.group(1)} ',
    );
    for (final token in expanded.split(RegExp(r'[\s]+'))) {
      // Signed query parameters can legally end in commas or semicolons.
      // Do not truncate those bytes: changing the URL can invalidate a token.
      // Keep legacy punctuation trimming for plain links pasted from prose.
      final unwrapped = token.trim().replaceAll(
        RegExp(r'^[<"\x27]+|[>"\x27]+$'), '',
      );
      final cleaned = unwrapped.contains('?')
          ? unwrapped
          : unwrapped.replaceAll(RegExp(r'[,;]+$'), '');
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
