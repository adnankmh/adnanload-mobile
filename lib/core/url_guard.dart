import 'dart:convert';

class UrlGuard {
  // Invisible controls can disguise a host, path or signed query when a
  // link is pasted from another app. Keep Arabic ZWNJ/ZWJ intact, but require
  // direction overrides and other non-printing controls to be percent-encoded.
  static final RegExp _hiddenUrlControls = RegExp(
    r'[\u0000-\u001F\u007F\u00AD\u061C\u200B\u200E\u200F\u2028-\u202E\u2060-\u206F\uFEFF]',
  );

  static Uri? validate(String input) {
    final trimmed = input.trim();
    if (_hiddenUrlControls.hasMatch(trimmed)) return null;
    Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
    // A trailing DNS root dot must not bypass local-host checks.
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.+$'), '');
    if (host.isEmpty || host.split('.').contains('') ||
        host == 'localhost' || host.endsWith('.localhost') ||
        host.endsWith('.local') || host.endsWith('.internal') ||
        host == '0.0.0.0' || host == '::1' || host.contains(':')) return null;
    final ip = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
    if (ip.hasMatch(host)) {
      // Other URL stacks may interpret zero-prefixed octets as octal.
      final octets = host.split('.');
      if (octets.any((part) => part.length > 1 && part.startsWith('0'))) {
        return null;
      }
      final parts = octets.map(int.parse).toList();
      if (parts.any((n) => n > 255) || parts[0] == 0 || parts[0] == 10 ||
          parts[0] == 127 || parts[0] >= 224 ||
          (parts[0] == 169 && parts[1] == 254) ||
          (parts[0] == 192 && parts[1] == 168) ||
          (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) ||
          (parts[0] == 100 && parts[1] >= 64 && parts[1] <= 127) ||
          // Special-use IPv4 networks are not public download endpoints.
          // Exclude documentation (TEST-NET), benchmarking and deprecated
          // 6to4 relay ranges; they must not enter the native download queue.
          // 192.0.0.0/24 is IETF protocol-assignment space, except the
          // globally reachable PCP/TURN anycast addresses .9 and .10.
          // Reject the rest before passing URLs to Android's native engine.
          (parts[0] == 192 && parts[1] == 0 && parts[2] == 0 &&
              parts[3] != 9 && parts[3] != 10) ||
          (parts[0] == 192 && parts[1] == 0 && parts[2] == 2) ||
          (parts[0] == 192 && parts[1] == 88 && parts[2] == 99) ||
          (parts[0] == 198 && (parts[1] == 18 || parts[1] == 19)) ||
          (parts[0] == 198 && parts[1] == 51 && parts[2] == 100) ||
          (parts[0] == 203 && parts[1] == 0 && parts[2] == 113)) return null;
    } else {
      // Shortened, decimal and hexadecimal IPv4 host aliases can resolve to
      // private addresses (127.1, 2130706433, 0x7f000001).
      final numericLabel = RegExp(r'^(?:[0-9]+|0x[0-9a-f]+)$');
      if (host.split('.').every(numericLabel.hasMatch)) return null;
    }
    return uri;
  }

  /// Reserve a distinct, portable filename before a job enters the queue.
  ///
  /// Keep the numeric suffix *inside* safeName's UTF-16/UTF-8 limits rather
  /// than appending it to an already truncated filename. Case-insensitive
  /// comparison avoids collisions when files are exported to other systems.
  /// Callers should include all persisted names, including canceled jobs:
  /// canceling a transfer does not prove its partial file was deleted.
  static String uniqueName(String requested, Iterable<String> occupied) {
    final original = safeName(requested);
    final taken = occupied.map((name) => name.toLowerCase()).toSet();
    if (!taken.contains(original.toLowerCase())) return original;

    final dot = original.lastIndexOf('.');
    final extension = dot > 0 && original.length - dot <= 20
        ? original.substring(dot)
        : '';
    final stem = extension.isEmpty ? original : original.substring(0, dot);

    // At most N occupied names can block N distinct numbered candidates.
    for (var number = 1; number <= taken.length + 1; number++) {
      final suffix = '_$number';
      final unitLimit = 160 - extension.length - suffix.length;
      final byteLimit = 240 - utf8.encode(extension).length -
          utf8.encode(suffix).length;
      final buffer = StringBuffer();
      var units = 0;
      var bytes = 0;
      for (final rune in stem.runes) {
        final character = String.fromCharCode(rune);
        final encodedLength = utf8.encode(character).length;
        if (units + character.length > unitLimit ||
            bytes + encodedLength > byteLimit) break;
        buffer.write(character);
        units += character.length;
        bytes += encodedLength;
      }
      final candidate = '${buffer.toString()}$suffix$extension';
      if (!taken.contains(candidate.toLowerCase())) return candidate;
    }
    throw StateError('Unable to allocate a distinct filename');
  }

  static String nameFromUrl(String url) {
    final uri = validate(url);
    if (uri == null) return 'download.bin';
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return safeName(last.isEmpty ? 'download.bin' : last);
  }

  /// Keep download names safe for Android storage and shared desktop exports.
  ///
  /// Preserve short extensions while respecting both UTF-16 and UTF-8 limits.
  /// Never split a surrogate pair or leave a misleading bidirectional marker.
  static String safeName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/<>:"|?*\x00-\x1F\x7F]'), '_')
        // Remove invisible direction/format controls that can disguise extensions
        // in Android lists and shared exports. Preserve ZWNJ/ZWJ because
        // they are meaningful in Arabic-script text and emoji sequences.
        .replaceAll(RegExp(r'[\u00AD\u061C\u200B\u200E\u200F\u2028-\u202E\u2060-\u206F\uFEFF]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      return 'download.bin';
    }

    // Windows treats these as devices even with an extension. Shared files
    // must remain portable, including COM3-COM9 and LPT3-LPT9.
    // Windows also reserves superscript COM/LPT digits and console aliases.
    final reserved = RegExp(
      r'^(CON|PRN|AUX|NUL|CONIN[$]|CONOUT[$]|(?:COM|LPT)[1-9¹²³])$',
      caseSensitive: false,
    );
    final normalized = reserved.hasMatch(cleaned.split('.').first.trimRight())
        ? '_' + cleaned
        : cleaned;

    const maxCodeUnits = 160;
    const maxUtf8Bytes = 240; // below common 255-byte filesystem limits
    final dot = normalized.lastIndexOf('.');
    final extension = dot > 0 && normalized.length - dot <= 20
        ? normalized.substring(dot)
        : '';
    final originalStem = extension.isEmpty
        ? normalized
        : normalized.substring(0, dot);
    final stemUnitLimit = maxCodeUnits - extension.length;
    final stemByteLimit = maxUtf8Bytes - utf8.encode(extension).length;

    final result = StringBuffer();
    var units = 0;
    var bytes = 0;
    for (final rune in originalStem.runes) {
      final character = String.fromCharCode(rune);
      final encodedLength = utf8.encode(character).length;
      if (units + character.length > stemUnitLimit ||
          bytes + encodedLength > stemByteLimit) {
        break;
      }
      result.write(character);
      units += character.length;
      bytes += encodedLength;
    }
    final stem = result.toString().replaceAll(RegExp(r'[. ]+$'), '');
    return (stem.isEmpty ? 'download' : stem) + extension;
  }
}
