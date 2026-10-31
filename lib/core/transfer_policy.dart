/// Pure, deterministic queue policy. Never bypasses the Android OS scheduler.
class TransferPolicy {
  static bool mayStart({required bool wifiOnly, required bool hasWifi,
    required bool hasNetwork, required int batteryPercent,
    required bool charging, required int batteryFloor,
    bool chargingOnly = false}) {
    if (!hasNetwork || (wifiOnly && !hasWifi)) return false;
    if (chargingOnly && !charging) return false;
    if (batteryFloor <= 0 || charging) return true;
    return batteryPercent >= batteryFloor;
  }

  static bool networkTransient(String failure) {
    final text = failure.toLowerCase();
    // Extractors commonly report "HTTP Error 429", while native clients can
    // report "status code: 503". Plain substring matching missed both forms.
    final codes = RegExp(
      r'\b(?:http(?:\s+(?:error|status(?:\s+code)?))?|status(?:\s+code)?)\s*[:=]?\s*(\d{3})\b',
    ).allMatches(text).map((match) => int.parse(match.group(1)!)).toSet();
    if (codes.any((code) => const {400, 401, 403, 404, 410, 451}.contains(code)) ||
        RegExp(r'\b(drm|widevine)\b|login required|sign in|private video|unsupported url|no space left|disk full|enospc').hasMatch(text)) {
      return false;
    }
    if (codes.any((code) => const {408, 425, 429, 500, 502, 503, 504}.contains(code))) {
      return true;
    }
    return const ['timeout', 'timed out', 'connection reset',
      'connection refused', 'connection closed', 'network unreachable', 'network is unreachable',
      'temporary failure', 'unable to resolve', 'socketexception',
      'too many requests', 'temporarily unavailable'].any(text.contains);
  }

  static Duration retryDelay(int attempt) {
    const seconds = [10, 30, 90];
    final index = (attempt - 1).clamp(0, seconds.length - 1).toInt();
    return Duration(seconds: seconds[index]);
  }

  static bool shouldRetry(String failure, int attempts,
      {bool enabled = true}) => enabled && attempts >= 0 && attempts < 3 && networkTransient(failure);
}
