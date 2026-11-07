import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/media_output.dart';

void main() {
  late Directory root;
  setUp(() async { root = await Directory.systemTemp.createTemp('adnanload-output-'); });
  tearDown(() async { await root.delete(recursive: true); });

  test('same title from different jobs never reuses an old download', () async {
    final first = MediaOutput.jobDirectory(root, 'first');
    final second = MediaOutput.jobDirectory(root, 'second');
    await first.create();
    await second.create();
    await File('${first.path}/video.mp4').writeAsBytes([1, 2, 3]);
    expect(await MediaOutput.singleFile(second, 'video', '${first.path}/video.mp4'), isNull);
    expect(await MediaOutput.singleFile(first, 'video', null), endsWith('video.mp4'));
    expect(MediaOutput.jobDirectory(root, 'first').path, first.path);
    expect(MediaOutput.jobDirectory(root, '../escape').parent.path, root.path);
  });

  test('sidecars, empty files and unfinished fragments are not complete media', () async {
    for (final name in ['video.info.json', 'cover.jpg', 'video.mp4.part', 'video.mp4.ytdl']) {
      await File('${root.path}/$name').writeAsBytes([1]);
    }
    await File('${root.path}/video.mp4').writeAsBytes([]);
    expect(await MediaOutput.singleFile(root, 'video', '${root.path}/cover.jpg'), isNull);
    expect(await MediaOutput.hasPlaylistMedia(root), isFalse);
    await File('${root.path}/video.mp3').writeAsBytes([1, 2]);
    expect(await MediaOutput.singleFile(root, 'video', null), endsWith('video.mp3'));
    expect(await MediaOutput.hasPlaylistMedia(root), isTrue);
  });

  test('ambiguous fallback and literal template tokens do not select arbitrary files', () async {
    final a = await File('${root.path}/video.mp4').writeAsBytes([1]);
    await File('${root.path}/video.webm').writeAsBytes([2]);
    expect(await MediaOutput.singleFile(root, 'video', null), isNull);
    expect(await MediaOutput.singleFile(root, 'video', a.path), a.path);
    expect(MediaOutput.basename('عنوان %(id)s.mp4'), 'عنوان _(id)s');
  });


  test('missing output folders and vanished media files are not completions', () async {
    final missing = Directory('${root.path}/removed-job');
    expect(await MediaOutput.singleFile(missing, 'video', null), isNull);
    expect(await MediaOutput.singleFile(
      missing, 'video', '${missing.path}/video.mp4',
    ), isNull);
    expect(await MediaOutput.hasPlaylistMedia(missing), isFalse);

    final removed = await File('${root.path}/vanished.mp4')
        .writeAsBytes([1, 2, 3]);
    await removed.delete();
    expect(await MediaOutput.isFinishedFile(removed), isFalse);
  });

  test('I/O failures during media scans fail closed without selecting files', () async {
    final existing = await File('${root.path}/video.mp4')
        .writeAsBytes([1]);
    expect(await MediaOutput.isFinishedFile(
      _VanishingFile(existing.path),
    ), isFalse);
    expect(await MediaOutput.singleFile(
      _UnavailableDirectory(root.path), 'video', null,
    ), isNull);
    expect(await MediaOutput.hasPlaylistMedia(
      _UnavailableDirectory(root.path),
    ), isFalse);
  });
}

class _VanishingFile implements File {
  _VanishingFile(this.path);

  @override
  final String path;

  @override
  Future<int> length() async =>
      throw const FileSystemException('File removed during stat');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnavailableDirectory implements Directory {
  _UnavailableDirectory(this.path);

  @override
  final String path;

  @override
  Future<bool> exists() async => true;

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) => Stream.error(const FileSystemException('Storage unavailable'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
