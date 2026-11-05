import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/backup_import_reader.dart';
import 'package:adnanload_mobile/services/backup_service.dart';

void main() {
  const validBackup = '{"application":"ADNANLOAD","schema":1,'
      '"history":[],"bookmarks":[],"preferences":{}}';

  test('streams valid backup across chunks and strips optional UTF-8 BOM',
      () async {
    final chunks = Stream<List<int>>.fromIterable([
      [0xEF],
      [0xBB, 0xBF],
      utf8.encode(validBackup.substring(0, 18)),
      utf8.encode(validBackup.substring(18)),
    ]);
    final decoded = await BackupImportReader.decodeStream(chunks);
    expect(BackupService.parse(decoded)['application'], 'ADNANLOAD');
  });

  test('rejects oversized SAF stream even with no reported file length',
      () async {
    final chunks = Stream<List<int>>.fromIterable([
      List<int>.filled(BackupImportReader.maxBytes, 0x20),
      [0x7B],
    ]);
    await expectLater(BackupImportReader.decodeStream(chunks),
        throwsFormatException);
  });

  test('rejects invalid UTF-8 and empty or BOM-only files', () async {
    for (final bytes in <List<int>>[
      [],
      [0xEF, 0xBB, 0xBF],
      [0x20, 0x0A, 0x09],
      [0xC3, 0x28],
    ]) {
      await expectLater(
        BackupImportReader.decodeStream(Stream.value(bytes)),
        throwsFormatException,
      );
    }
  });

  test('preflight accepts unknown and boundary sizes but rejects oversize',
      () {
    expect(() => BackupImportReader.checkReportedLength(null), returnsNormally);
    expect(() => BackupImportReader.checkReportedLength(
        BackupImportReader.maxBytes), returnsNormally);
    expect(() => BackupImportReader.checkReportedLength(
        BackupImportReader.maxBytes + 1), throwsFormatException);
    expect(() => BackupImportReader.checkReportedLength(-1),
        throwsFormatException);
  });

  test('stream decoding preserves non-ASCII history and validates schema',
      () async {
    final backup = validBackup.replaceFirst('"bookmarks":[]',
        '"bookmarks":["https://example.org/ملف"]');
    final decoded = await BackupImportReader.decodeStream(
        Stream.value(utf8.encode(backup)));
    expect((BackupService.parse(decoded)['bookmarks'] as List).single,
        'https://example.org/ملف');
    await expectLater(BackupImportReader.decodeStream(
        Stream.value(utf8.encode('not json'))), completion('not json'));
    expect(() => BackupService.parse('not json'), throwsFormatException);
  });
}
