import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'url_guard.dart';

/// Keep each queued job's output separate, even when titles are identical.
class MediaOutput {
  static Directory jobDirectory(Directory root, String processId) => Directory(
    '${root.path}${Platform.pathSeparator}job-${sha256.convert(utf8.encode(processId))}',
  );

  // A user title is literal text, never a yt-dlp template expression.
  static String basename(String title) => UrlGuard.safeName(title.replaceFirst(
    RegExp(r'\.(mp3|mp4|webm|m4a|flac|wav|opus)$', caseSensitive: false), ''),
  ).replaceAll('%', '_');

  static bool isMediaPath(String path) => RegExp(
    r'\.(mp4|mkv|webm|mov|avi|m4v|3gp|ts|mpeg|mpg|mp3|m4a|flac|wav|opus|ogg|aac|mka|weba|aiff|alac|mp2|ac3|amr|wma|wmv)$',
    caseSensitive: false,
  ).hasMatch(path);

  static Future<bool> isFinishedFile(File file) async {
    if (!isMediaPath(file.path)) return false;
    try {
      return await FileSystemEntity.type(file.path, followLinks: false) ==
              FileSystemEntityType.file &&
          await file.length() > 0;
    } on FileSystemException {
      // Native jobs may remove or replace a destination during verification.
      return false;
    }
  }

  // A successful extractor callback must point to the requested job output,
  // not an unrelated media file left in the same directory.
  static bool _matchesBasename(File file, String basename) =>
      file.path.split(Platform.pathSeparator).last.startsWith('$basename.');

  static Future<String?> singleFile(Directory output, String basename,
      String? reportedPath) async {
    if (reportedPath != null && reportedPath.isNotEmpty) {
      final reported = File(reportedPath);
      if (reported.absolute.parent.path == output.absolute.path &&
          _matchesBasename(reported, basename) &&
          await isFinishedFile(reported)) return reported.path;
    }
    final candidates = <String>[];
    try {
      await for (final entity in output.list(followLinks: false)) {
        if (entity is File &&
            _matchesBasename(entity, basename) &&
            await isFinishedFile(entity)) {
          candidates.add(entity.path);
        }
      }
    } on FileSystemException {
      // A cleanup or storage revocation can invalidate the directory mid-scan.
      return null;
    }
    return candidates.length == 1 ? candidates.single : null;
  }

  static Future<bool> hasPlaylistMedia(Directory directory) async {
    try {
      if (!await directory.exists()) return false;
      await for (final entity in directory.list(
          recursive: true, followLinks: false)) {
        if (entity is File && await isFinishedFile(entity)) return true;
      }
    } on FileSystemException {
      // A playlist output may disappear while the extractor is shutting down.
      return false;
    }
    return false;
  }
}
