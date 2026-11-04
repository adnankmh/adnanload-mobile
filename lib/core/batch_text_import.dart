import 'dart:convert';
import 'dart:typed_data';

/// Decodes a user-selected plain-text link list. No network access or
/// background clipboard access is involved.
class BatchTextImport {
  static const int maxBytes = 1024 * 1024;

  static String decode(List<int> bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('TXT file exceeds 1 MiB');
    }
    final decoded = utf8.decode(bytes);
    final text = decoded.startsWith('\uFEFF') ? decoded.substring(1) : decoded;
    if (text.trim().isEmpty) {
      throw const FormatException('TXT file is empty');
    }
    return text;
  }

  /// Stream Android SAF files with a strict limit, including when the picker
  /// cannot report their length. Never load an unbounded file into memory.
  static Future<String> decodeStream(Stream<List<int>> chunks) async {
    // SAF providers may recycle mutable buffers between stream events.
    // Snapshot each chunk so later writes cannot corrupt earlier URLs.
    final buffer = BytesBuilder(copy: true);
    await for (final chunk in chunks) {
      if (chunk.length > maxBytes - buffer.length) {
        throw const FormatException('TXT file exceeds 1 MiB');
      }
      buffer.add(chunk);
    }
    return decode(buffer.takeBytes());
  }
}
