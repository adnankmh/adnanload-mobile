import 'dart:io';

import 'package:adnanload_mobile/core/media_conversion_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('adnanload-convert-');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('unchanged nonempty input and distinct output are accepted', () async {
    final source = await File('${root.path}/source.mp4').writeAsBytes([1, 2]);
    final output = await File('${root.path}/source.mp3').writeAsBytes([3, 4]);
    final snapshot = await MediaConversionGuard.captureSource(source);

    expect(await MediaConversionGuard.sourceUnchanged(source, snapshot), isTrue);
    expect(await MediaConversionGuard.outputIsUsable(output, snapshot), isTrue);
  });

  test('modified or removed source invalidates conversion', () async {
    final source = await File('${root.path}/source.mp4').writeAsBytes([1]);
    final snapshot = await MediaConversionGuard.captureSource(source);

    await source.writeAsBytes([1, 2, 3]);
    expect(await MediaConversionGuard.sourceUnchanged(source, snapshot), isFalse);
    await source.delete();
    expect(await MediaConversionGuard.sourceUnchanged(source, snapshot), isFalse);
  });

  test('empty and missing inputs cannot be converted', () async {
    final empty = await File('${root.path}/empty.mp4').create();
    final missing = File('${root.path}/missing.mp4');

    expect(
      MediaConversionGuard.captureSource(empty),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      MediaConversionGuard.captureSource(missing),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('empty, missing and directory outputs are rejected', () async {
    final source = await File('${root.path}/source.mp4').writeAsBytes([1]);
    final snapshot = await MediaConversionGuard.captureSource(source);
    final empty = await File('${root.path}/empty.mp3').create();
    final directory = await Directory('${root.path}/folder.mp3').create();

    expect(await MediaConversionGuard.outputIsUsable(empty, snapshot), isFalse);
    expect(
      await MediaConversionGuard.outputIsUsable(
        File('${root.path}/missing.mp3'),
        snapshot,
      ),
      isFalse,
    );
    expect(
      await MediaConversionGuard.outputIsUsable(File(directory.path), snapshot),
      isFalse,
    );
    expect(
      await MediaConversionGuard.destinationOccupied(File(directory.path)),
      isTrue,
    );
  });

  test('dangling symlinks reserve names and cannot be accepted as output',
      () async {
    final source = await File('${root.path}/source.mp4').writeAsBytes([1]);
    final snapshot = await MediaConversionGuard.captureSource(source);
    final link = Link('${root.path}/output.mp3');
    await link.create('${root.path}/nonexistent.mp3');

    expect(await MediaConversionGuard.destinationOccupied(File(link.path)), isTrue);
    expect(
      await MediaConversionGuard.outputIsUsable(File(link.path), snapshot),
      isFalse,
    );
  });

  test('cleanup removes partial regular files but preserves symlinks and input',
      () async {
    final source = await File('${root.path}/source.mp4').writeAsBytes([1]);
    final partial = await File('${root.path}/partial.mp3').writeAsBytes([2]);
    await MediaConversionGuard.removePartialOutput(
      partial,
      protectedSource: source,
    );
    expect(await partial.exists(), isFalse);

    final link = Link('${root.path}/alias.mp3');
    await link.create(source.path);
    final snapshot = await MediaConversionGuard.captureSource(source);
    expect(
      await MediaConversionGuard.outputIsUsable(File(link.path), snapshot),
      isFalse,
    );
    await MediaConversionGuard.removePartialOutput(File(link.path));
    expect(await link.exists(), isTrue);
    expect(await source.readAsBytes(), [1]);
  });
  test('hard-linked output is rejected and cannot be deleted as partial output',
      () async {
    final source = await File('${root.path}/source.mp4').writeAsBytes([1, 2, 3]);
    final alias = File('${root.path}/hardlink.mp3');
    final linkResult = await Process.run('ln', [source.path, alias.path]);
    expect(linkResult.exitCode, 0, reason: '${linkResult.stderr}');
    final snapshot = await MediaConversionGuard.captureSource(source);

    expect(await MediaConversionGuard.outputIsUsable(alias, snapshot), isFalse);
    await MediaConversionGuard.removePartialOutput(
      alias,
      protectedSource: source,
    );
    expect(await alias.exists(), isTrue);
    expect(await source.readAsBytes(), [1, 2, 3]);
  }, skip: Platform.isWindows);
}
