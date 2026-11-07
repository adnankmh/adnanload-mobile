import 'dart:io';

import 'package:adnanload_mobile/models/download_entry.dart';
import 'package:adnanload_mobile/services/storage_audit.dart';
import 'package:flutter_test/flutter_test.dart';

DownloadEntry _complete(String id, String path) => DownloadEntry(
      id: id,
      url: 'https://example.org/archive.bin',
      name: 'archive.bin',
      kind: 'direct',
      status: 'complete',
      path: path,
      addedAt: 1,
    );

void main() {
  late Directory temp;
  late File original;
  late File hardLink;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('adnanload-hardlinks-');
    original = File('${temp.path}/original.bin');
    hardLink = File('${temp.path}/hard-link.bin');
    await original.writeAsBytes([10, 20, 30, 40]);
    // Hard links share the same inode but resolveSymbolicLinks() leaves their
    // different names intact. CI runs on Linux; Windows skips these tests.
    final created = await Process.run('ln', [original.path, hardLink.path]);
    expect(created.exitCode, 0, reason: '${created.stderr}');
    expect(
      await FileSystemEntity.identical(original.path, hardLink.path),
      isTrue,
    );
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('hard-link aliases alone are not duplicate downloads', () async {
    final groups = await StorageAudit.findDuplicates([
      _complete('original', original.path),
      _complete('hard-link', hardLink.path),
    ]);
    expect(groups, isEmpty);
  }, skip: Platform.isWindows);

  test('hard-link alias is excluded from a genuine duplicate group', () async {
    final copy = File('${temp.path}/copy.bin');
    await copy.writeAsBytes([10, 20, 30, 40]);

    final groups = await StorageAudit.findDuplicates([
      _complete('original', original.path),
      _complete('hard-link', hardLink.path),
      _complete('copy', copy.path),
    ]);
    expect(groups, hasLength(1));
    expect(groups.single.map((entry) => entry.id).toSet(),
        equals({'original', 'copy'}));
  }, skip: Platform.isWindows);

  test('recorded storage counts each hard-linked inode only once', () async {
    final copy = File('${temp.path}/copy.bin');
    await copy.writeAsBytes([10, 20, 30, 40]);
    final total = await StorageAudit.recordedBytes([
      _complete('original', original.path),
      _complete('hard-link', hardLink.path),
      _complete('copy', copy.path),
    ]);
    expect(total, 8); // 4 bytes in original + 4 in independent copy.
  }, skip: Platform.isWindows);
}
