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
    final decoded = _decodeBytes(bytes);
    final text = decoded.startsWith('\uFEFF') ? decoded.substring(1) : decoded;
    if (text.trim().isEmpty) {
      throw const FormatException('TXT file is empty');
    }
    return text;
  }

  /// Windows text editors often save URL lists as UTF-16 with a BOM.
  /// Only recognize BOM-marked UTF-16; guessing encodings could silently
  /// change signed URLs. Validate surrogate pairs rather than replacing
  /// malformed bytes with Unicode replacement characters.
  static String _decodeBytes(List<int> bytes) {
    if (bytes.length < 2 ||
        !((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
          (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
      return utf8.decode(bytes);
    }

    final littleEndian = bytes[0] == 0xFF;
    // UTF-32LE starts with FF FE 00 00; do not misread it as UTF-16.
    if (littleEndian && bytes.length >= 4 &&
        bytes[2] == 0 && bytes[3] == 0) {
      throw const FormatException('Unsupported TXT encoding');
    }
    if ((bytes.length - 2).isOdd) {
      throw const FormatException('Malformed UTF-16 TXT');
    }

    int unitAt(int offset) => littleEndian
        ? bytes[offset] | (bytes[offset + 1] << 8)
        : (bytes[offset] << 8) | bytes[offset + 1];

    final units = <int>[];
    for (var i = 2; i < bytes.length; i += 2) {
      final unit = unitAt(i);
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        if (i + 3 >= bytes.length) {
          throw const FormatException('Malformed UTF-16 TXT');
        }
        final low = unitAt(i + 2);
        if (low < 0xDC00 || low > 0xDFFF) {
          throw const FormatException('Malformed UTF-16 TXT');
        }
        units.add(unit);
        units.add(low);
        i += 2;
      } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
        throw const FormatException('Malformed UTF-16 TXT');
      } else {
        units.add(unit);
      }
    }
    return String.fromCharCodes(units);
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
