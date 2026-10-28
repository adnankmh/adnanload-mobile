/// Pure, deterministic queue policy. Never bypasses the Android OS scheduler.
class TransferPolicy {
  static bool mayStart({required bool wifiOnly, required bool hasWifi,
    required bool hasNetwork, required int batteryPercent,
    required bool charging, required int batteryFloor}) {
    if (!hasNetwork || (wifiOnly && !hasWifi)) return false;
    if (batteryFloor <= 0 || charging) return true;
    return batteryPercent >= batteryFloor;
  }

  static bool networkTransient(String failure) {
    final text = failure.toLowerCase();
    return const ['timeout', 'timed out', 'connection reset',
      'connection refused', 'connection closed', 'network unreachable',
      'temporary failure', 'unable to resolve', 'socketexception',
      'http 429', 'http 502', 'http 503', 'http 504'].any(text.contains);
  }

  static Duration retryDelay(int attempt) {
    const seconds = [10, 30, 90];
    final index = (attempt - 1).clamp(0, seconds.length - 1).toInt();
    return Duration(seconds: seconds[index]);
  }

  static bool shouldRetry(String failure, int attempts,
      {bool enabled = true}) => enabled && attempts < 3 && networkTransient(failure);
}
