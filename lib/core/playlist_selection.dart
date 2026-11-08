import 'playlist_rules.dart';

/// Expands explicit positions into bounded independent transfer tasks.
/// Empty selection (entire playlist) is intentionally NOT expanded.
class PlaylistSelection {
  /// Encode explicitly selected positions without accidentally selecting extra
  /// playlist items. Long consecutive runs are represented as inclusive
  /// ranges so selecting all 100 previewed entries fits the parser's 200-
  /// character limit. Sparse selections that cannot fit are rejected rather
  /// than silently widening a range or producing an unusable expression.
  static String compact(Iterable<int> indices) {
    final sorted = indices.toSet().toList()..sort();
    // An empty explicit selection must never mean 'download the entire playlist'.
    if (sorted.isEmpty) {
      throw const FormatException('No playlist items selected');
    }
    if (sorted.length > 100 || sorted.first < 1 || sorted.last > 100000) {
      throw const FormatException('Invalid playlist selection');
    }

    final ranges = <String>[];
    var start = sorted.first;
    var end = start;
    for (final position in sorted.skip(1)) {
      if (position == end + 1) {
        end = position;
      } else {
        ranges.add(start == end ? '$start' : '$start-$end');
        start = position;
        end = position;
      }
    }
    ranges.add(start == end ? '$start' : '$start-$end');
    final expression = ranges.join(',');
    if (expression.length > 200) {
      throw const FormatException('Playlist selection is too long');
    }
    return expression;
  }

  static List<int> expand(String raw, {int limit = 100}) {
    final expression = PlaylistRules.parseItems(raw);
    if (expression.isEmpty) return const [];
    final result = <int>{};
    for (final term in expression.split(',')) {
      final pieces = term.split(RegExp(r'[-:]'));
      final first = int.parse(pieces[0]);
      final last = pieces.length == 1 ? first : int.parse(pieces[1]);
      if (last - first > limit || first > 100000 || last > 100000) {
        throw const FormatException('Too many playlist items');
      }
      for (int n = first; n <= last; n++) {
        result.add(n);
        if (result.length > limit) throw const FormatException('Too many playlist items');
      }
    }
    return result.toList()..sort();
  }
}
