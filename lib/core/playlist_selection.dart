import 'playlist_rules.dart';

/// Expands explicit positions into bounded independent transfer tasks.
/// Empty selection (entire playlist) is intentionally NOT expanded.
class PlaylistSelection {
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
