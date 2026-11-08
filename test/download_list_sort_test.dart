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

  test('name sorting uses natural order for numbered downloads', () {
    final parts = [
      item('ten', 'Episode10.mp4', 10, 5),
      item('two', 'episode2.mp4', 20, 5),
      item('one', 'EPISODE1.mp4', 30, 5),
      item('twenty', 'episode20.mp4', 40, 5),
    ];
    expect(DownloadListSort.ordered(parts, 'name').map((e) => e.id),
        ['one', 'two', 'ten', 'twenty']);
    expect(parts.map((e) => e.id), ['ten', 'two', 'one', 'twenty']);
  });

  test('long numeric runs do not overflow and leading zeros tie by date', () {
    final files = [
      item('huge', 'part999999999999999999999999999999.zip', 10, 5),
      item('small', 'part2.zip', 20, 5),
      item('padded', 'part0002.zip', 30, 5),
      item('next', 'part1000000000000000000000000000000.zip', 40, 5),
    ];
    expect(DownloadListSort.ordered(files, 'name').map((e) => e.id),
        ['padded', 'small', 'huge', 'next']);
  });

  test('Arabic filenames with numbered parts sort naturally', () {
    final files = [
      item('ten', 'الجزء10.pdf', 10, 5),
      item('two', 'الجزء2.pdf', 20, 5),
    ];
    expect(DownloadListSort.ordered(files, 'name').map((e) => e.id),
        ['two', 'ten']);
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

  test('next scheduled lists pending jobs chronologically, not completed ones', () {
    final early = item('early', 'early.zip', 10, 5)..scheduledAt = 100;
    final late = item('late', 'late.zip', 20, 5)..scheduledAt = 300;
    final completed = item('done', 'done.zip', 30, 5)
      ..scheduledAt = 50
      ..status = 'complete';
    final unscheduled = item('now', 'now.zip', 40, 5);
    final ordered = DownloadListSort.ordered(
        [unscheduled, late, completed, early], 'scheduled');
    expect(ordered.map((e) => e.id), ['early', 'late', 'now', 'done']);
    expect(early.scheduledAt, 100);
    expect(completed.status, 'complete');
  });

  test('invalid schedule times are treated as unscheduled', () {
    final invalid = item('invalid', 'bad.zip', 40, 5)
      ..scheduledAt = -10;
    final zero = item('zero', 'zero.zip', 30, 5);
    final pending = item('pending', 'pending.zip', 10, 5)
      ..scheduledAt = 200;
    expect(DownloadListSort.ordered([invalid, zero, pending], 'scheduled')
        .map((e) => e.id), ['pending', 'invalid', 'zero']);
  });

  test('equal schedule times fall back to newest date then stable id', () {
    final a = item('a', 'A', 10, 5)..scheduledAt = 100;
    final z = item('z', 'Z', 10, 5)..scheduledAt = 100;
    final newer = item('new', 'N', 20, 5)..scheduledAt = 100;
    expect(DownloadListSort.ordered([z, a, newer], 'scheduled')
        .map((e) => e.id), ['new', 'a', 'z']);
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
    expect(DownloadListSort.label('scheduled', arabic: true),
        'المجدولة الأقرب أولاً');
    expect(DownloadListSort.label('scheduled', arabic: false),
        'Next scheduled');
    expect(DownloadListSort.modes, hasLength(5));
  });
}
