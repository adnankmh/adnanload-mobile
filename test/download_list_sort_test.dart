import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/download_list_sort.dart';
import 'package:adnanload_mobile/models/download_entry.dart';

DownloadEntry item(String id, String name, int at, int priority) =>
    DownloadEntry(
      id: id,
      url: 'https://example.org/$id',
      name: name,
      kind: 'direct',
      status: 'waiting',
      addedAt: at,
      priority: priority,
    );

void main() {
  final a = item('a', 'Zulu.zip', 10, 5);
  final b = item('b', 'alpha.pdf', 30, 1);
  final c = item('c', 'Beta.mp4', 20, 3);
  final source = <DownloadEntry>[a, b, c];

  test('newest is default and oldest reverses date order', () {
    expect(DownloadListSort.ordered(source, 'newest').map((e) => e.id),
        ['b', 'c', 'a']);
    expect(DownloadListSort.ordered(source, 'oldest').map((e) => e.id),
        ['a', 'c', 'b']);
    expect(DownloadListSort.ordered(source, 'unexpected').map((e) => e.id),
        ['b', 'c', 'a']);
  });

  test('name sort ignores case and priority matches native queue order', () {
    expect(DownloadListSort.ordered(source, 'name').map((e) => e.id),
        ['b', 'c', 'a']);
    expect(DownloadListSort.ordered(source, 'priority').map((e) => e.id),
        ['b', 'c', 'a']);
  });

  test('sorting never mutates the repository snapshot or queue priorities', () {
    DownloadListSort.ordered(source, 'priority');
    DownloadListSort.ordered(source, 'oldest');
    expect(source.map((e) => e.id), ['a', 'b', 'c']);
    expect(source.map((e) => e.priority), [5, 1, 3]);
  });

  test('ties are deterministic and use recent date before id', () {
    final x = item('z', 'Same', 30, 2);
    final y = item('a', 'same', 30, 2);
    final z = item('c', 'Same', 10, 2);
    for (final mode in DownloadListSort.modes) {
      final sorted = DownloadListSort.ordered([x, z, y], mode);
      expect(sorted.map((e) => e.id),
          mode == 'oldest' ? ['c', 'a', 'z'] : ['a', 'z', 'c']);
    }
  });

  test('empty and singleton lists are safe', () {
    expect(DownloadListSort.ordered(<DownloadEntry>[], 'name'), isEmpty);
    expect(DownloadListSort.ordered([a], 'priority'), [a]);
  });

  test('sort labels are localized without changing stored language', () {
    expect(DownloadListSort.label('priority', arabic: true),
        'حسب أولوية الطابور');
    expect(DownloadListSort.label('priority', arabic: false),
        'Queue priority');
    expect(DownloadListSort.modes, hasLength(4));
  });
}
