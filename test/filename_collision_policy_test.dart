import 'dart:convert';

import 'package:adnanload_mobile/core/url_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps a safe filename when it is not already reserved', () {
    expect(UrlGuard.uniqueName('report.pdf', const []), 'report.pdf');
    expect(UrlGuard.uniqueName('CON.txt', const []), '_CON.txt');
  });

  test('allocates the next suffix across case-insensitive history', () {
    expect(
      UrlGuard.uniqueName(
        'report.pdf',
        const ['REPORT.PDF', 'report_1.pdf', 'Report_2.PDF'],
      ),
      'report_3.pdf',
    );
    // Canceled records are still supplied by the repository: their partial
    // files may survive native cancellation and must not be overwritten.
    expect(UrlGuard.uniqueName('report.pdf', const ['report.pdf']),
        'report_1.pdf');
  });

  test('keeps suffix and extension within the UTF-16 filename limit', () {
    final original = '${List.filled(156, 'a').join()}.zip';
    final result = UrlGuard.uniqueName(original, [original]);
    expect(result.endsWith('_1.zip'), isTrue);
    expect(result.length, lessThanOrEqualTo(160));
    expect(result, isNot(original));
  });

  test('does not split Unicode runes or exceed the UTF-8 byte limit', () {
    final original = '${List.filled(100, '界').join()}.mp4';
    final sanitized = UrlGuard.safeName(original);
    final result = UrlGuard.uniqueName(original, [sanitized]);
    expect(result.endsWith('_1.mp4'), isTrue);
    expect(result.runes.every((rune) => rune != 0xfffd), isTrue);
    expect(result.length, lessThanOrEqualTo(160));
    expect(utf8.encode(result).length, lessThanOrEqualTo(240));
  });

  test('handles collision chains with a long original name', () {
    final original = '${List.filled(160, 'x').join()}';
    final first = UrlGuard.uniqueName(original, [original]);
    final second = UrlGuard.uniqueName(original, [original, first]);
    expect(first.endsWith('_1'), isTrue);
    expect(second.endsWith('_2'), isTrue);
    expect({original, first, second}.length, 3);
    expect(second.length, lessThanOrEqualTo(160));
  });
}
