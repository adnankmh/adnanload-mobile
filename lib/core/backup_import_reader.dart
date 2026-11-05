import 'dart:convert';
import 'dart:typed_data';

/// Bounded UTF-8 reader for user-selected backup files.
///
/// SAF providers may not report a size. Never call readAsBytes() on an
/// untrusted document: reject oversized input while consuming the stream.
/// BackupService.parse still validates the JSON schema and entry limits.
class BackupImportReader {
  static const int maxBytes = 5 * 1024 * 1024;

  static void checkReportedLength(int? length) {
    if (length != null && (length < 0 || length > maxBytes)) {
      throw const FormatException('Backup exceeds 5 MiB');
    }
  }

  static Future<String> decodeStream(Stream<List<int>> chunks) async {
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in chunks) {
      if (chunk.length > maxBytes - buffer.length) {
        throw const FormatException('Backup exceeds 5 MiB');
      }
      buffer.add(chunk);
    }
    if (buffer.length == 0) {
      throw const FormatException('Backup is empty');
    }
    // utf8.decode rejects malformed input rather than silently replacing
    // invalid bytes in a security-sensitive restore file.
    final decoded = utf8.decode(buffer.takeBytes());
    final text = decoded.startsWith('\uFEFF')
        ? decoded.substring(1)
        : decoded;
    if (text.trim().isEmpty) {
      throw const FormatException('Backup is empty');
    }
    return text;
  }
}
