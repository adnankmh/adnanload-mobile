import 'dart:convert';

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
}
