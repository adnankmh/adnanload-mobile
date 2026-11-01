import 'dart:io';

import 'package:crypto/crypto.dart';

/// Inspect a completed native transfer without reviving a canceled/removed job.
///
/// The caller supplies a live state check, which is re-evaluated after every
/// asynchronous operation. Returning null means the result must be discarded.
class DirectCompletionVerifier {
  DirectCompletionVerifier._();

  static Future<DirectCompletionResult?> inspect({
    required Future<String> Function() resolvePath,
    required String fallbackPath,
    required String expectedSha256,
    required bool Function() isCurrent,
    Future<String> Function(File)? hashFile,
  }) async {
    if (!isCurrent()) return null;
    var path = fallbackPath;
    try {
      final resolved = await resolvePath();
      if (resolved.isNotEmpty) path = resolved;
    } catch (_) {
      // Old native tasks may not resolve their path; use persisted metadata.
    }
    if (!isCurrent()) return null;
    if (path.isEmpty) return DirectCompletionResult.missing(path);

    try {
      final file = File(path);
      if (!await file.exists() || await file.length() <= 0) {
        if (!isCurrent()) return null;
        return DirectCompletionResult.missing(path);
      }
      if (!isCurrent()) return null;
      if (expectedSha256.isEmpty) return DirectCompletionResult.success(path);
      try {
        final actual = await (hashFile == null
            ? sha256.bind(file.openRead()).first.then((digest) => digest.toString())
            : hashFile(file));
        if (!isCurrent()) return null;
        return actual.toLowerCase() == expectedSha256.toLowerCase()
            ? DirectCompletionResult.success(path, actualSha256: actual)
            : DirectCompletionResult(
                path: path, status: 'error', error: 'checksumMismatch',
                actualSha256: actual);
      } catch (_) {
        if (!isCurrent()) return null;
        return DirectCompletionResult(
          path: path, status: 'error', error: 'verificationFailed');
      }
    } catch (_) {
      if (!isCurrent()) return null;
      return DirectCompletionResult.missing(path);
    }
  }
}

class DirectCompletionResult {
  const DirectCompletionResult({
    required this.path,
    required this.status,
    required this.error,
    this.actualSha256 = '',
  });

  final String path;
  final String status;
  final String error;
  final String actualSha256;

  const DirectCompletionResult.success(this.path, {this.actualSha256 = ''})
      : status = 'complete', error = '';

  const DirectCompletionResult.missing(this.path)
      : status = 'error', error = 'downloadedFileMissing', actualSha256 = '';
}
