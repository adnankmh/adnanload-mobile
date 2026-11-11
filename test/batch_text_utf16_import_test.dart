import 'dart:convert';

import 'package:adnanload_mobile/core/batch_links.dart';
import 'package:adnanload_mobile/core/batch_text_import.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> utf16WithBom(String text, {required bool littleEndian}) {
  final bytes = <int>[if (littleEndian) ...[0xFF, 0xFE] else ...[0xFE, 0xFF]];
  for (final unit in text.codeUnits) {
    if (littleEndian) {
      bytes.addAll([unit & 0xFF, unit >> 8]);
    } else {
      bytes.addAll([unit >> 8, unit & 0xFF]);
    }
  }
  return bytes;
}

void main() {
  test('imports Windows UTF-16LE and UTF-16BE URL lists', () {
    const input = 'روابط 😀\r\nhttps://example.org/a.zip\r\n'
        'https://example.org/b.pdf\r\n';
    for (final littleEndian in [true, false]) {
      final decoded = BatchTextImport.decode(
        utf16WithBom(input, littleEndian: littleEndian),
      );
      expect(decoded, input);
      expect(BatchLinks.parse(decoded), [
        'https://example.org/a.zip',
        'https://example.org/b.pdf',
      ]);
    }
  });

  test('stream decoding accepts a UTF-16 BOM split across SAF chunks', () async {
    final bytes = utf16WithBom(
      'https://example.org/a.zip\n',
      littleEndian: true,
    );
    final chunks = Stream<List<int>>.fromIterable([
      bytes.sublist(0, 1),
      bytes.sublist(1, 3),
      bytes.sublist(3),
    ]);
    expect(BatchLinks.parse(await BatchTextImport.decodeStream(chunks)),
        ['https://example.org/a.zip']);
  });

  test('rejects odd-length and unpaired UTF-16 surrogate sequences', () {
    for (final bytes in <List<int>>[
      [0xFF, 0xFE, 0x61],
      [0xFF, 0xFE, 0x00, 0xD8],
      [0xFF, 0xFE, 0x00, 0xDC],
      [0xFF, 0xFE, 0x00, 0xD8, 0x41, 0x00],
      [0xFE, 0xFF, 0xD8, 0x00, 0x00, 0x41],
      [0xFF, 0xFE, 0x00, 0x00, 0x00, 0x00],
      [0xFF, 0xFE],
    ]) {
      expect(() => BatchTextImport.decode(bytes), throwsFormatException,
          reason: bytes.toString());
    }
  });

  test('retains strict UTF-8 handling for files without a UTF-16 BOM', () {
    const input = 'https://example.org/a.zip\n';
    expect(BatchTextImport.decode(utf8.encode(input)), input);
    expect(() => BatchTextImport.decode([0xC3, 0x28]),
        throwsFormatException);
  });

  test('UTF-16 imports still filter unsafe and duplicate destinations', () {
    final input = utf16WithBom(
      'http://127.0.0.1/admin\nhttps://example.org/a.zip\n'
      'https://example.org/a.zip\n',
      littleEndian: false,
    );
    expect(BatchLinks.parse(BatchTextImport.decode(input)),
        ['https://example.org/a.zip']);
  });

  test('UTF-16 streams still enforce the 1 MiB limit', () async {
    final oversized = List<int>.filled(BatchTextImport.maxBytes + 1, 0);
    oversized[0] = 0xFF;
    oversized[1] = 0xFE;
    final chunks = Stream<List<int>>.fromIterable([
      oversized.sublist(0, 2),
      oversized.sublist(2),
    ]);
    await expectLater(BatchTextImport.decodeStream(chunks),
        throwsFormatException);
  });
}
