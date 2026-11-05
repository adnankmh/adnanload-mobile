import 'dart:io';

/// Filesystem checks around an FFmpeg conversion. Never treat a partial or
/// replaced output as a successfully converted download.
class MediaSourceSnapshot {
  const MediaSourceSnapshot({
    required this.canonicalPath,
    required this.size,
    required this.modified,
    required this.changed,
  });

  final String canonicalPath;
  final int size;
  final DateTime modified;
  final DateTime changed;
}

class MediaConversionGuard {
  MediaConversionGuard._();

  static Future<MediaSourceSnapshot> captureSource(File source) async {
    final canonicalPath = await source.resolveSymbolicLinks();
    final stat = await source.stat();
    if (stat.type != FileSystemEntityType.file || stat.size <= 0) {
      throw FileSystemException('Input missing or empty', source.path);
    }
    return MediaSourceSnapshot(
      canonicalPath: canonicalPath,
      size: stat.size,
      modified: stat.modified,
      changed: stat.changed,
    );
  }

  static Future<bool> sourceUnchanged(
    File source,
    MediaSourceSnapshot original,
  ) async {
    try {
      final current = await captureSource(source);
      return current.canonicalPath == original.canonicalPath &&
          current.size == original.size &&
          current.modified == original.modified &&
          current.changed == original.changed;
    } on FileSystemException {
      return false;
    }
  }

  /// Unlike File.exists(), this also reserves dangling symlinks and directories
  /// so the converter cannot select an already occupied output name.
  static Future<bool> destinationOccupied(File destination) async {
    return await FileSystemEntity.type(
          destination.path,
          followLinks: false,
        ) !=
        FileSystemEntityType.notFound;
  }

  static Future<bool> outputIsUsable(
    File output,
    MediaSourceSnapshot source,
  ) async {
    try {
      // A symlink must not redirect FFmpeg output onto an existing file.
      if (await FileSystemEntity.type(
            output.path,
            followLinks: false,
          ) !=
          FileSystemEntityType.file) {
        return false;
      }
      final canonicalPath = await output.resolveSymbolicLinks();
      if (canonicalPath == source.canonicalPath) return false;
      final stat = await output.stat();
      return stat.type == FileSystemEntityType.file && stat.size > 0;
    } on FileSystemException {
      return false;
    }
  }

  /// Only remove a regular output file created for this attempt. In particular,
  /// never follow or delete a symlink that may have appeared in its place.
  static Future<void> removePartialOutput(File output) async {
    try {
      if (await FileSystemEntity.type(
            output.path,
            followLinks: false,
          ) ==
          FileSystemEntityType.file) {
        await output.delete();
      }
    } on FileSystemException {
      // Preserve the original conversion failure if cleanup is unavailable.
    }
  }
}
