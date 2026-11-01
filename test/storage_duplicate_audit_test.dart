import 'dart:io';

import 'package:adnanload_mobile/models/download_entry.dart';
import 'package:adnanload_mobile/services/storage_audit.dart';
import 'package:flutter_test/flutter_test.dart';

DownloadEntry completed(String id, String path,
    {String status = 'complete', bool playlist = false}) {
  return DownloadEntry(
    id: id,
    url: 'https://example.org/file.bin',
    name: 'file.bin',
    kind: 'direct',
    status: status,
    path: path,
    addedAt: 1,
    isPlaylist: playlist,
  );
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('adnanload-duplicates-');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('repeated history records for one path are not duplicate files', () async {
    final file = File('${temp.path}/single.bin');
    await file.writeAsBytes([1, 2, 3]);

    final groups = await StorageAudit.findDuplicates([
      completed('first', file.path),
      completed('second', file.path),
    ]);

    expect(groups, isEmpty);
  });

  test('identical distinct files are duplicates, same-size different files are not',
      () async {
    final first = File('${temp.path}/first.bin');
    final second = File('${temp.path}/second.bin');
    final different = File('${temp.path}/different.bin');
    await first.writeAsBytes([1, 2, 3]);
    await second.writeAsBytes([1, 2, 3]);
    await different.writeAsBytes([1, 2, 4]);

    final groups = await StorageAudit.findDuplicates([
      completed('first', first.path),
      completed('first-again', first.path),
      completed('second', second.path),
      completed('different', different.path),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.map((entry) => entry.id).toSet(),
        equals({'first', 'second'}));
  });

  test('ignores empty, missing, unfinished and playlist files', () async {
    final empty1 = File('${temp.path}/empty1.bin');
    final empty2 = File('${temp.path}/empty2.bin');
    final unfinished = File('${temp.path}/unfinished.bin');
    await empty1.writeAsBytes([]);
    await empty2.writeAsBytes([]);
    await unfinished.writeAsBytes([7, 8]);

    final groups = await StorageAudit.findDuplicates([
      completed('empty1', empty1.path),
      completed('empty2', empty2.path),
      completed('missing', '${temp.path}/missing.bin'),
      completed('paused', unfinished.path, status: 'paused'),
      completed('playlist', unfinished.path, playlist: true),
    ]);

    expect(groups, isEmpty);
  });

  test('path and symlink aliases do not masquerade as duplicate files', () async {
    final original = File('${temp.path}/original.bin');
    final copy = File('${temp.path}/copy.bin');
    final nested = Directory('${temp.path}/nested');
    await nested.create();
    await original.writeAsBytes([9, 8, 7]);
    await copy.writeAsBytes([9, 8, 7]);
    final alias = Link('${temp.path}/alias.bin');
    await alias.create(original.path);

    final groups = await StorageAudit.findDuplicates([
      completed('original', original.path),
      completed('dot-alias', '${nested.path}/../original.bin'),
      completed('symlink-alias', alias.path),
      completed('copy', copy.path),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.map((entry) => entry.id).toSet(),
        equals({'original', 'copy'}));
  });
}
