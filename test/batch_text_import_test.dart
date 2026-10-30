import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/batch_links.dart';
import 'package:adnanload_mobile/core/batch_text_import.dart';

void main() {
  test('imports UTF-8 with optional BOM and Windows newlines', () {
    final bytes = <int>[0xEF, 0xBB, 0xBF,
      ...utf8.encode('https://example.org/a.zip\r\nhttps://example.org/b.pdf\r\n')];
    expect(BatchLinks.parse(BatchTextImport.decode(bytes)), [
      'https://example.org/a.zip', 'https://example.org/b.pdf',
    ]);
  });

  test('rejects empty, malformed UTF-8 and oversized text', () {
    expect(() => BatchTextImport.decode([]), throwsFormatException);
    expect(() => BatchTextImport.decode(utf8.encode('  \n  ')),
        throwsFormatException);
    expect(() => BatchTextImport.decode([0xC3, 0x28]),
        throwsFormatException);
    expect(() => BatchTextImport.decode(
        List<int>.filled(BatchTextImport.maxBytes + 1, 0x61)),
        throwsFormatException);
  });

  test('streams TXT with a BOM split across chunks', () async {
    final chunks = Stream<List<int>>.fromIterable([
      [0xEF], [0xBB, 0xBF],
      utf8.encode('https://example.org/a.zip\r\n'),
    ]);
    expect(await BatchTextImport.decodeStream(chunks),
        'https://example.org/a.zip\r\n');
  });

  test('rejects an oversized stream even if length was not reported', () async {
    final chunks = Stream<List<int>>.fromIterable([
      List<int>.filled(BatchTextImport.maxBytes, 0x61),
      [0x62],
    ]);
    await expectLater(BatchTextImport.decodeStream(chunks),
        throwsFormatException);
  });

  test('imported private and duplicate URLs remain filtered', () {
    final input = utf8.encode(
      'https://example.org/a.zip\nhttp://127.0.0.1/admin\n'
      'https://example.org/a.zip\nhttps://example.org/b.pdf');
    expect(BatchLinks.parse(BatchTextImport.decode(input),
        existing: {'https://example.org/b.pdf'}),
        ['https://example.org/a.zip']);
  });
}
