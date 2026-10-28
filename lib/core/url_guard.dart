class UrlGuard {
  static Uri? validate(String input) {
    Uri? uri = Uri.tryParse(input.trim());
    if (uri == null || !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host.endsWith('.localhost') ||
        host.endsWith('.local') || host.endsWith('.internal') ||
        host == '0.0.0.0' || host == '::1' || host.contains(':')) return null;
    final ip = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
    if (ip.hasMatch(host)) {
      final parts = host.split('.').map(int.parse).toList();
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
