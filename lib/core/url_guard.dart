class UrlGuard {
  static Uri? validate(String input) {
    Uri? uri = Uri.tryParse(input.trim());
    if (uri == null || !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
    // A trailing DNS root dot is valid and must not bypass local-host checks.
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\\.+
      if (parts.any((n) => n > 255) || parts[0] == 0 || parts[0] == 10 ||
          parts[0] == 127 || parts[0] >= 224 ||
          (parts[0] == 169 && parts[1] == 254) ||
          (parts[0] == 192 && parts[1] == 168) ||
          (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) ||
          (parts[0] == 100 && parts[1] >= 64 && parts[1] <= 127)) return null;
    } else {
      // Browsers and network libraries may interpret shortened, decimal or
      // hexadecimal IPv4 hostnames as private IPs (127.1, 2130706433,
      // 0x7f000001). Reject numeric aliases rather than relying on DNS.
      final numericLabel = RegExp(r'^(?:[0-9]+|0x[0-9a-f]+)

  static String nameFromUrl(String url) {
    final uri = validate(url);
    if (uri == null) return 'download.bin';
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return safeName(last.isEmpty ? 'download.bin' : last);
  }

  static String safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/<>:"|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ').trim().replaceAll(RegExp(r'[. ]+$'), '');
    final forbidden = {'CON','PRN','AUX','NUL','COM1','COM2','LPT1','LPT2'};
    final base = cleaned.split('.').first.toUpperCase();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return 'download.bin';
    return '${forbidden.contains(base) ? '_' : ''}${cleaned.length > 160 ? cleaned.substring(0, 160) : cleaned}';
  }
}
), '');
    if (host.isEmpty || host.split('.').contains('') ||
        host == 'localhost' || host.endsWith('.localhost') ||
        host.endsWith('.local') || host.endsWith('.internal') ||
        host == '0.0.0.0' || host == '::1' || host.contains(':')) return null;
    final ip = RegExp(r'^\\d{1,3}(\\.\\d{1,3}){3}
      if (parts.any((n) => n > 255) || parts[0] == 0 || parts[0] == 10 ||
          parts[0] == 127 || parts[0] >= 224 ||
          (parts[0] == 169 && parts[1] == 254) ||
          (parts[0] == 192 && parts[1] == 168) ||
          (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) ||
          (parts[0] == 100 && parts[1] >= 64 && parts[1] <= 127)) return null;
    }
    return uri;
  }

  static String nameFromUrl(String url) {
    final uri = validate(url);
    if (uri == null) return 'download.bin';
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return safeName(last.isEmpty ? 'download.bin' : last);
  }

  static String safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/<>:"|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ').trim().replaceAll(RegExp(r'[. ]+$'), '');
    final forbidden = {'CON','PRN','AUX','NUL','COM1','COM2','LPT1','LPT2'};
    final base = cleaned.split('.').first.toUpperCase();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return 'download.bin';
    return '${forbidden.contains(base) ? '_' : ''}${cleaned.length > 160 ? cleaned.substring(0, 160) : cleaned}';
  }
}
);
    if (ip.hasMatch(host)) {
      // Leading zero octets can be interpreted as octal by other URL stacks.
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
          (parts[0] == 100 && parts[1] >= 64 && parts[1] <= 127)) return null;
    }
    return uri;
  }

  static String nameFromUrl(String url) {
    final uri = validate(url);
    if (uri == null) return 'download.bin';
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return safeName(last.isEmpty ? 'download.bin' : last);
  }

  static String safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/<>:"|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ').trim().replaceAll(RegExp(r'[. ]+$'), '');
    final forbidden = {'CON','PRN','AUX','NUL','COM1','COM2','LPT1','LPT2'};
    final base = cleaned.split('.').first.toUpperCase();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return 'download.bin';
    return '${forbidden.contains(base) ? '_' : ''}${cleaned.length > 160 ? cleaned.substring(0, 160) : cleaned}';
  }
}
);
      if (host.split('.').every(numericLabel.hasMatch)) return null;
    }
    return uri;
  }

  static String nameFromUrl(String url) {
    final uri = validate(url);
    if (uri == null) return 'download.bin';
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return safeName(last.isEmpty ? 'download.bin' : last);
  }

  static String safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/<>:"|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ').trim().replaceAll(RegExp(r'[. ]+$'), '');
    final forbidden = {'CON','PRN','AUX','NUL','COM1','COM2','LPT1','LPT2'};
    final base = cleaned.split('.').first.toUpperCase();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return 'download.bin';
    return '${forbidden.contains(base) ? '_' : ''}${cleaned.length > 160 ? cleaned.substring(0, 160) : cleaned}';
  }
}
), '');
    if (host.isEmpty || host.split('.').contains('') ||
        host == 'localhost' || host.endsWith('.localhost') ||
        host.endsWith('.local') || host.endsWith('.internal') ||
        host == '0.0.0.0' || host == '::1' || host.contains(':')) return null;
    final ip = RegExp(r'^\\d{1,3}(\\.\\d{1,3}){3}
      if (parts.any((n) => n > 255) || parts[0] == 0 || parts[0] == 10 ||
          parts[0] == 127 || parts[0] >= 224 ||
          (parts[0] == 169 && parts[1] == 254) ||
          (parts[0] == 192 && parts[1] == 168) ||
          (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) ||
          (parts[0] == 100 && parts[1] >= 64 && parts[1] <= 127)) return null;
    }
    return uri;
  }

  static String nameFromUrl(String url) {
    final uri = validate(url);
    if (uri == null) return 'download.bin';
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return safeName(last.isEmpty ? 'download.bin' : last);
  }

  static String safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/<>:"|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ').trim().replaceAll(RegExp(r'[. ]+$'), '');
    final forbidden = {'CON','PRN','AUX','NUL','COM1','COM2','LPT1','LPT2'};
    final base = cleaned.split('.').first.toUpperCase();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return 'download.bin';
    return '${forbidden.contains(base) ? '_' : ''}${cleaned.length > 160 ? cleaned.substring(0, 160) : cleaned}';
  }
}
);
    if (ip.hasMatch(host)) {
      // Leading zero octets can be interpreted as octal by other URL stacks.
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
          (parts[0] == 100 && parts[1] >= 64 && parts[1] <= 127)) return null;
    }
    return uri;
  }

  static String nameFromUrl(String url) {
    final uri = validate(url);
    if (uri == null) return 'download.bin';
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return safeName(last.isEmpty ? 'download.bin' : last);
  }

  static String safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/<>:"|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ').trim().replaceAll(RegExp(r'[. ]+$'), '');
    final forbidden = {'CON','PRN','AUX','NUL','COM1','COM2','LPT1','LPT2'};
    final base = cleaned.split('.').first.toUpperCase();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return 'download.bin';
    return '${forbidden.contains(base) ? '_' : ''}${cleaned.length > 160 ? cleaned.substring(0, 160) : cleaned}';
  }
}
