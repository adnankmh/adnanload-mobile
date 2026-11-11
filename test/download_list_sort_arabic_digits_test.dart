import 'package:adnanload_mobile/core/download_list_sort.dart';
import 'package:adnanload_mobile/models/download_entry.dart';
import 'package:flutter_test/flutter_test.dart';

DownloadEntry download(String id, String name, int addedAt) => DownloadEntry(
      id: id,
      url: 'https://example.org/$id',
      name: name,
      kind: 'direct',
      status: 'waiting',
      addedAt: addedAt,
    );

void main() {
  test('Arabic-Indic and Eastern Arabic-Indic digits sort numerically', () {
    final items = [
      download('ten', 'الجزء١٠.pdf', 10),
      download('three', 'الجزء۳.pdf', 20),
      download('two', 'الجزء٢.pdf', 30),
      download('eleven', 'الجزء11.pdf', 40),
    ];
    expect(DownloadListSort.ordered(items, 'name').map((e) => e.id),
        ['two', 'three', 'ten', 'eleven']);
  });

  test('mixed digit scripts within a single number are compared by value', () {
    final items = [
      download('thirteen', 'clip١3.mp4', 10),
      download('twelve', 'clip1٢.mp4', 20),
      download('four', 'clip۴.mp4', 30),
    ];
    expect(DownloadListSort.ordered(items, 'name').map((e) => e.id),
        ['four', 'twelve', 'thirteen']);
  });

  test('cross-script leading zeros tie and keep newest-first fallback', () {
    final items = [
      download('older', 'ملف2.zip', 10),
      download('newer', 'ملف۰۰٢.zip', 30),
      download('middle', 'ملف٠02.zip', 20),
    ];
    expect(DownloadListSort.ordered(items, 'name').map((e) => e.id),
        ['newer', 'middle', 'older']);
    expect(items.map((e) => e.id), ['older', 'newer', 'middle']);
  });

  test('very long Arabic digit runs sort without integer overflow', () {
    final smaller = download('small', 'part٢.zip', 10);
    final huge = download('huge', 'part${List.filled(90, '٩').join()}.zip', 20);
    final larger = download('larger', 'part١${List.filled(90, '٠').join()}.zip', 30);
    expect(DownloadListSort.ordered([larger, huge, smaller], 'name')
        .map((e) => e.id), ['small', 'huge', 'larger']);
  });
}
