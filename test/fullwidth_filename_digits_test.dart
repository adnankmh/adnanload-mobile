import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/download_list_sort.dart';
import 'package:adnanload_mobile/core/filename_search.dart';
import 'package:adnanload_mobile/models/download_entry.dart';

DownloadEntry entry(String id, String name, int date) => DownloadEntry(
  id: id, url: 'https://example.org/$id', name: name,
  kind: 'direct', status: 'waiting', addedAt: date, priority: 5,
);

void main() {
  test('fullwidth digits sort naturally across numeral scripts', () {
    final entries = [
      entry('ten', 'Part１０.zip', 10),
      entry('two', 'Part２.zip', 20),
      entry('arabic', 'Part٢.zip', 30),
      entry('one', 'Part1.zip', 40),
    ];
    expect(DownloadListSort.ordered(entries, 'name').map((e) => e.id),
        ['one', 'arabic', 'two', 'ten']);
    expect(entries.first.name, 'Part１０.zip');
  });

  test('filename search matches fullwidth and Arabic digits without mutation', () {
    expect(FilenameSearch.contains('Part１２.zip', 'part12'), isTrue);
    expect(FilenameSearch.contains('Part١٢.zip', 'part１２'), isTrue);
    expect(FilenameSearch.contains('Part１２.zip', 'part13'), isFalse);
  });
}
