import 'package:adnanload_mobile/core/playlist_rules.dart';
import 'package:adnanload_mobile/core/playlist_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compresses the full 100-item preview into a valid expression', () {
    final selected = List<int>.generate(100, (index) => index + 1);
    final expression = PlaylistSelection.compact(selected);
    expect(expression, '1-100');
    expect(PlaylistRules.parseItems(expression), expression);
    expect(PlaylistSelection.expand(expression), selected);
  });

  test('sorts and deduplicates positions without widening gaps', () {
    final expression = PlaylistSelection.compact([12, 3, 2, 11, 1, 10, 2, 5]);
    expect(expression, '1-3,5,10-12');
    expect(PlaylistSelection.expand(expression), [1, 2, 3, 5, 10, 11, 12]);
  });

  test('supports empty, singleton and separated selections', () {
    expect(() => PlaylistSelection.compact([]), throwsFormatException);
    expect(PlaylistSelection.compact([7]), '7');
    expect(PlaylistSelection.compact([1, 3, 5]), '1,3,5');
  });

  test('rejects selections outside the supported position bounds', () {
    expect(() => PlaylistSelection.compact([0, 1]), throwsFormatException);
    expect(() => PlaylistSelection.compact([-1]), throwsFormatException);
    expect(() => PlaylistSelection.compact([100001]), throwsFormatException);
  });

  test('rejects more than 100 distinct selections', () {
    expect(
      () => PlaylistSelection.compact(
        List<int>.generate(101, (index) => index + 1),
      ),
      throwsFormatException,
    );
  });

  test('rejects sparse selections exceeding the parser limit', () {
    final sparse = List<int>.generate(100, (index) => index * 2 + 1);
    expect(() => PlaylistSelection.compact(sparse), throwsFormatException);
  });

  test('never converts an empty explicit selection into a full-playlist request', () {
    expect(() => PlaylistSelection.compact(<int>[]), throwsFormatException);
    // The empty parser expression intentionally means the whole playlist,
    // so explicit selection encoding must not return it.
    expect(PlaylistRules.parseItems(''), '');
  });

  test('round trips a 100-item selection at the maximum supported index', () {
    final selected = List<int>.generate(100, (index) => 99901 + index);
    final expression = PlaylistSelection.compact(selected);
    expect(expression, '99901-100000');
    expect(PlaylistSelection.expand(expression), selected);
  });

  test('preserves separated runs and never includes unselected positions', () {
    final selected = [1, 2, 3, 7, 8, 10, 20, 21, 23, 100000];
    final expression = PlaylistSelection.compact(selected.reversed);
    expect(expression, '1-3,7-8,10,20-21,23,100000');
    expect(PlaylistSelection.expand(expression), selected);
  });
}
