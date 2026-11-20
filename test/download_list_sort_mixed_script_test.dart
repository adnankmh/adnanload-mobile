import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/download_list_sort.dart';
import 'package:adnanload_mobile/models/download_entry.dart';

DownloadEntry entry(String id, String name) => DownloadEntry(
      id: id,
      url: 'https://example.org/$id',
      name: name,
      kind: 'direct',
      status: 'waiting',
      addedAt: 1,
    );

void main() {
  test('mixed numeral scripts sort consistently against letters', () {
    final items = [
      entry('a', 'part٢.zip'),
      entry('b', 'partA.zip'),
      entry('c', 'part2.zip'),
      entry('d', 'part۲.zip'),
      entry('e', 'part10.zip'),
    ];
    for (var i = 0; i < items.length; i++) {
      final rotated = [...items.skip(i), ...items.take(i)];
      expect(DownloadListSort.ordered(rotated, 'name').map((e) => e.id),
          ['a', 'c', 'd', 'e', 'b']);
      expect(DownloadListSort.ordered(rotated.reversed, 'name').map((e) => e.id),
          ['a', 'c', 'd', 'e', 'b']);
    }
  });

  test('punctuation and letters keep consistent digit token ordering', () {
    final items = [
      entry('a', 'file-1'),
      entry('b', 'file٠'),
      entry('c', 'file0'),
      entry('d', 'file۹'),
      entry('e', 'file10'),
      entry('f', 'file:'),
      entry('g', 'filez'),
    ];
    expect(DownloadListSort.ordered(items.reversed, 'name').map((e) => e.id),
        ['a', 'b', 'c', 'd', 'e', 'f', 'g']);
  });
}
