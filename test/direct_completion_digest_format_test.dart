import 'dart:io';

import 'package:adnanload_mobile/core/direct_completion_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('adnanload-digest-format-');
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('malformed restored checksums fail before expensive hashing', () async {
    final file = await File('${temp.path}/download.bin').writeAsBytes([97, 98, 99]);
    var hashes = 0;
    final invalidDigests = <String>[
      'abc123',
      List.filled(64, 'g').join(),
      ' ${List.filled(64, '0').join()}',
    ];
    for (final digest in invalidDigests) {
      final result = await DirectCompletionVerifier.inspect(
        resolvePath: () async => file.path,
        fallbackPath: '',
        expectedSha256: digest,
        isCurrent: () => true,
        hashFile: (_) async {
          hashes++;
          return digest;
        },
      );
      expect(result?.status, 'error');
      expect(result?.error, 'verificationFailed');
    }
    expect(hashes, 0);
  });

  test('valid uppercase SHA-256 still verifies successfully', () async {
    final file = await File('${temp.path}/download.bin').writeAsBytes([97, 98, 99]);
    final result = await DirectCompletionVerifier.inspect(
      resolvePath: () async => file.path,
      fallbackPath: '',
      expectedSha256:
          'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD',
      isCurrent: () => true,
    );
    expect(result?.status, 'complete');
    expect(result?.error, isEmpty);
  });

  test('missing file remains missing even with a malformed digest', () async {
    final result = await DirectCompletionVerifier.inspect(
      resolvePath: () async => '${temp.path}/absent.bin',
      fallbackPath: '',
      expectedSha256: 'not-a-sha256',
      isCurrent: () => true,
    );
    expect(result?.error, 'downloadedFileMissing');
  });

  test('optional checksum still completes without invoking hashing', () async {
    final file = await File('${temp.path}/unchecked.bin').writeAsBytes([1, 2, 3]);
    var hashCalls = 0;
    final result = await DirectCompletionVerifier.inspect(
      resolvePath: () async => file.path,
      fallbackPath: '',
      expectedSha256: '',
      isCurrent: () => true,
      hashFile: (_) async {
        hashCalls++;
        return 'unexpected';
      },
    );
    expect(result?.status, 'complete');
    expect(result?.error, isEmpty);
    expect(hashCalls, 0);
  });

  test('well-formed but incorrect checksum remains a mismatch', () async {
    final file = await File('${temp.path}/wrong.bin').writeAsBytes([97, 98, 99]);
    final result = await DirectCompletionVerifier.inspect(
      resolvePath: () async => file.path,
      fallbackPath: '',
      expectedSha256: List.filled(64, '0').join(),
      isCurrent: () => true,
    );
    expect(result?.status, 'error');
    expect(result?.error, 'checksumMismatch');
    expect(result?.actualSha256,
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });
}
