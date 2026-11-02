import 'dart:io';

import 'package:adnanload_mobile/core/media_output.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory output;

  setUp(() async {
    output = await Directory.systemTemp.createTemp('adnanload-reported-media-');
  });

  tearDown(() async {
    await output.delete(recursive: true);
  });

  test('unrelated reported media is not mistaken for a completed job', () async {
    final unrelated = File('${output.path}/old-video.mp4');
    await unrelated.writeAsBytes([1, 2, 3]);

    expect(await MediaOutput.singleFile(output, 'video', unrelated.path), isNull);
  });

  test('unrelated reported path falls back to the requested output', () async {
    final unrelated = File('${output.path}/old-video.mp4');
    final requested = File('${output.path}/video.mp4');
    await unrelated.writeAsBytes([1, 2, 3]);
    await requested.writeAsBytes([4, 5, 6]);

    expect(
      await MediaOutput.singleFile(output, 'video', unrelated.path),
      requested.path,
    );
  });

  test('matching reported output resolves ambiguous valid media extensions',
      () async {
    final mp4 = File('${output.path}/video.mp4');
    final webm = File('${output.path}/video.webm');
    await mp4.writeAsBytes([1]);
    await webm.writeAsBytes([2]);

    expect(await MediaOutput.singleFile(output, 'video', null), isNull);
    expect(await MediaOutput.singleFile(output, 'video', webm.path), webm.path);
  });

  test('a similar title is not accepted as the requested basename', () async {
    final similar = File('${output.path}/video-final.mp4');
    await similar.writeAsBytes([1]);

    expect(await MediaOutput.singleFile(output, 'video', similar.path), isNull);
  });
}
