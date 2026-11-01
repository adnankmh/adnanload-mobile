import 'dart:async';
import 'dart:io';

import 'package:adnanload_mobile/core/direct_completion_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('adnanload-completion-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('accepts a real nonempty file and an expected SHA-256', () async {
    final file = await File('${root.path}/data.bin').writeAsBytes([97, 98, 99]);
    final result = await DirectCompletionVerifier.inspect(
      resolvePath: () async => file.path,
      fallbackPath: '',
      expectedSha256:
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      isCurrent: () => true,
    );
    expect(result?.status, 'complete');
    expect(result?.path, file.path);
    expect(result?.actualSha256, isNotEmpty);
  });

  test('rejects checksum mismatches and empty or missing files', () async {
    final file = await File('${root.path}/data.bin').writeAsBytes([1]);
    final bad = await DirectCompletionVerifier.inspect(
      resolvePath: () async => file.path,
      fallbackPath: '',
      expectedSha256: '0' * 64,
      isCurrent: () => true,
    );
    expect(bad?.error, 'checksumMismatch');
    expect(bad?.status, 'error');
    await file.writeAsBytes([]);
    final empty = await DirectCompletionVerifier.inspect(
      resolvePath: () async => file.path,
      fallbackPath: '',
      expectedSha256: '',
      isCurrent: () => true,
    );
    expect(empty?.error, 'downloadedFileMissing');
    final missing = await DirectCompletionVerifier.inspect(
      resolvePath: () async => '${root.path}/absent.bin',
      fallbackPath: '',
      expectedSha256: '',
      isCurrent: () => true,
    );
    expect(missing?.error, 'downloadedFileMissing');
  });

  test('falls back to persisted path when native lookup fails', () async {
    final file = await File('${root.path}/old.bin').writeAsBytes([1]);
    final result = await DirectCompletionVerifier.inspect(
      resolvePath: () async => throw const FileSystemException('No task'),
      fallbackPath: file.path,
      expectedSha256: '',
      isCurrent: () => true,
    );
    expect(result?.status, 'complete');
    expect(result?.path, file.path);
  });

  test('cancel during asynchronous native path lookup discards completion', () async {
    final pending = Completer<String>();
    var active = true;
    final inspection = DirectCompletionVerifier.inspect(
      resolvePath: () => pending.future,
      fallbackPath: '',
      expectedSha256: '',
      isCurrent: () => active,
    );
    active = false;
    pending.complete('${root.path}/old.bin');
    expect(await inspection, isNull);
  });

  test('cancel during checksum computation cannot revive the job', () async {
    final file = await File('${root.path}/data.bin').writeAsBytes([1]);
    final pending = Completer<String>();
    final hashing = Completer<void>();
    var active = true;
    final inspection = DirectCompletionVerifier.inspect(
      resolvePath: () async => file.path,
      fallbackPath: '',
      expectedSha256: '0' * 64,
      isCurrent: () => active,
      hashFile: (_) {
        hashing.complete();
        return pending.future;
      },
    );
    await hashing.future;
    active = false;
    pending.complete('0' * 64);
    expect(await inspection, isNull);
  });
}
