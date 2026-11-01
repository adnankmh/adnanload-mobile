import 'dart:async';
import 'dart:io';

import 'package:adnanload_mobile/core/direct_completion_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('adnanload-stable-file-');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  const digest =
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

  Future<DirectCompletionResult?> inspectWhileHashing(
      File file, Future<void> Function() mutate) async {
    final started = Completer<void>();
    final release = Completer<String>();
    final inspection = DirectCompletionVerifier.inspect(
      resolvePath: () async => file.path,
      fallbackPath: '',
      expectedSha256: digest,
      isCurrent: () => true,
      hashFile: (_) {
        started.complete();
        return release.future;
      },
    );
    await started.future;
    await mutate();
    // Simulate a matching digest from a hash operation that was already
    // running when another actor changed the destination on disk.
    release.complete(digest);
    return inspection;
  }

  test('rejects a file truncated while its checksum is being computed', () async {
    final file = await File('${root.path}/truncated.bin')
        .writeAsBytes([97, 98, 99, 100]);
    final result = await inspectWhileHashing(file, () async {
      await file.writeAsBytes([97], flush: true);
    });
    expect(result?.status, 'error');
    expect(result?.error, 'verificationFailed');
  });

  test('rejects same-length replacement with changed modification time', () async {
    final file = await File('${root.path}/replaced.bin')
        .writeAsBytes([97, 98, 99]);
    final result = await inspectWhileHashing(file, () async {
      await file.writeAsBytes([120, 121, 122], flush: true);
      await file.setLastModified(DateTime.utc(2020, 1, 1));
    });
    expect(result?.status, 'error');
    expect(result?.error, 'verificationFailed');
  });

  test('rejects destination removed while checksum is in progress', () async {
    final file = await File('${root.path}/removed.bin')
        .writeAsBytes([97, 98, 99]);
    final result = await inspectWhileHashing(file, () async {
      await file.delete();
    });
    expect(result?.status, 'error');
    expect(result?.error, 'verificationFailed');
  });

  test('does not mistake a directory for a downloaded file', () async {
    final dir = await Directory('${root.path}/directory').create();
    final result = await DirectCompletionVerifier.inspect(
      resolvePath: () async => dir.path,
      fallbackPath: '',
      expectedSha256: '',
      isCurrent: () => true,
    );
    expect(result?.status, 'error');
    expect(result?.error, 'downloadedFileMissing');
  });
}
