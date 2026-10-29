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
}
