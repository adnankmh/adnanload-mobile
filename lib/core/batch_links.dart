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
    // Ordinary Markdown destinations may contain balanced literal
    // parentheses, e.g. file(2).zip or a signed token=(a,b). The simple
    // Markdown regex below cannot parse those nested delimiters. Expand
    // only complete, public HTTP(S) destinations, without rewriting their
    // signed query bytes or changing bare URLs.
    final balancedExpanded = _expandBalancedMarkdownDestinations(text);
    final angleExpanded = balancedExpanded.replaceAllMapped(
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

  /// Extract Markdown URLs containing balanced literal parentheses.
  ///
  /// A bounded scan avoids treating malformed Markdown as an unlimited URL
  /// and keeps all other Markdown/bare-link parsing on the existing path.
  static String _expandBalancedMarkdownDestinations(String text) {
    final markdownOpen = RegExp(r'!?\[[^\]\r\n]*\]\(');
    final httpStart = RegExp(r'^https?://', caseSensitive: false);
    final whitespace = RegExp(r'\s');
    final output = StringBuffer();
    var copiedThrough = 0;

    for (final match in markdownOpen.allMatches(text)) {
      if (match.start < copiedThrough) continue;
      final start = match.end;
      final prefixEnd = start + 8 < text.length ? start + 8 : text.length;
      if (!httpStart.hasMatch(text.substring(start, prefixEnd))) continue;

      var depth = 1;
      var hasInnerParenthesis = false;
      var closing = -1;
      for (var index = start;
          index < text.length && index - start < 8192;
          index++) {
        final character = text[index];
        if (whitespace.hasMatch(character) ||
            character == '<' || character == '>') break;
        if (character == '(') {
          hasInnerParenthesis = true;
          if (++depth > 16) break;
        } else if (character == ')') {
          if (--depth == 0) {
            closing = index;
            break;
          }
        }
      }
      if (!hasInnerParenthesis || closing < 0) continue;
      final destination = text.substring(start, closing);
      if (UrlGuard.validate(destination) == null) continue;
      output.write(text.substring(copiedThrough, match.start));
      output.write(' $destination ');
      copiedThrough = closing + 1;
    }
    output.write(text.substring(copiedThrough));
    return output.toString();
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
