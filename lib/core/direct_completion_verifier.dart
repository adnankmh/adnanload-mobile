import 'dart:io';

import 'package:crypto/crypto.dart';

/// Inspect a completed native transfer without reviving a canceled/removed job.
///
/// The caller supplies a live state check, which is re-evaluated after every
/// asynchronous operation. Returning null means the result must be discarded.
class DirectCompletionVerifier {
  DirectCompletionVerifier._();

  static bool _sameFileGeneration(
    FileStat before,
    FileStat after,
    String canonicalBefore,
    String canonicalAfter,
  ) =>
      before.type == FileSystemEntityType.file &&
      after.type == FileSystemEntityType.file &&
      before.size == after.size &&
      before.modified == after.modified &&
      before.changed == after.changed &&
      canonicalBefore == canonicalAfter;

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
      // A directory or an empty/missing file is never a completed transfer.
      // Capture file metadata before hashing: the native destination can be
      // replaced or truncated while the asynchronous digest is in progress.
      // A path can be a symlink: retain the resolved destination so a
      // retarget during verification cannot validate the wrong file.
      final canonicalBefore = await file.resolveSymbolicLinks();
      if (!isCurrent()) return null;
      final before = await file.stat();
      if (before.type != FileSystemEntityType.file || before.size <= 0) {
        if (!isCurrent()) return null;
        return DirectCompletionResult.missing(path);
      }
      if (!isCurrent()) return null;
      if (expectedSha256.isEmpty) {
        // A native completion callback is the transfer authority when no
        // checksum was provided. Recheck the file generation before trusting
        // its destination; this is not a substitute for an expected digest.
        try {
          final after = await file.stat();
          if (!isCurrent()) return null;
          final canonicalAfter = await file.resolveSymbolicLinks();
          if (!isCurrent()) return null;
          return _sameFileGeneration(
            before, after, canonicalBefore, canonicalAfter,
          )
              ? DirectCompletionResult.success(path)
              : DirectCompletionResult(
                  path: path, status: 'error', error: 'verificationFailed');
        } catch (_) {
          if (!isCurrent()) return null;
          return DirectCompletionResult(
            path: path, status: 'error', error: 'verificationFailed');
        }
      }
      // Enqueue validates user-entered digests, but restored history may be
      // corrupted or edited. Never hash a potentially large completed file
      // for a malformed persisted checksum, and never treat it as unchecked.
      if (!RegExp(r'^[0-9a-fA-F]{64}
            ? sha256.bind(file.openRead()).first.then((digest) => digest.toString())
            : hashFile(file));
        if (!isCurrent()) return null;
        final after = await file.stat();
        if (!isCurrent()) return null;
        final canonicalAfter = await file.resolveSymbolicLinks();
        if (!isCurrent()) return null;
        // A matching digest is not sufficient if a symlink was retargeted or
        // the underlying file was replaced while hashing.
        if (!_sameFileGeneration(
          before, after, canonicalBefore, canonicalAfter,
        )) {
          return DirectCompletionResult(
            path: path, status: 'error', error: 'verificationFailed');
        }
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
).hasMatch(expectedSha256)) {
        if (!isCurrent()) return null;
        return DirectCompletionResult(
          path: path, status: 'error', error: 'verificationFailed');
      }
      try {
        final actual = await (hashFile == null
            ? sha256.bind(file.openRead()).first.then((digest) => digest.toString())
            : hashFile(file));
        if (!isCurrent()) return null;
        final after = await file.stat();
        if (!isCurrent()) return null;
        final canonicalAfter = await file.resolveSymbolicLinks();
        if (!isCurrent()) return null;
        // A matching digest is not sufficient if a symlink was retargeted or
        // the underlying file was replaced while hashing.
        if (!_sameFileGeneration(
          before, after, canonicalBefore, canonicalAfter,
        )) {
          return DirectCompletionResult(
            path: path, status: 'error', error: 'verificationFailed');
        }
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
