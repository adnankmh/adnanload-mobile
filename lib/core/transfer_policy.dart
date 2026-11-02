import 'dart:io';

import '../models/download_entry.dart';
import 'url_guard.dart';

/// Deterministic queue policy. Never bypasses the Android OS scheduler.
class TransferPolicy {
  /// Limit concurrent in-app direct transfers per host, regardless of scheme
  /// or port. Scheduled Android jobs remain owned by WorkManager.
  static String? directHost(String url) {
    // Apply the same public-URL guard used at enqueue time. Persisted history
    // and external intents must not claim queue capacity for local, credential-
    // bearing or malformed addresses.
    final uri = UrlGuard.validate(url);
    if (uri == null) return null;
    // All trailing DNS root dots are equivalent for per-host throttling.
    return uri.host.toLowerCase().replaceFirst(RegExp(r'\.+$'), '');
  }

  static void countDirectHost(String url, Map<String, int> counts) {
    final host = directHost(url);
    if (host == null) return;
    counts[host] = (counts[host] ?? 0) + 1;
  }

  static bool mayStartDirectHost(String url, Map<String, int> counts,
      {int maxPerHost = 2}) {
    final host = directHost(url);
    return host != null && maxPerHost > 0 &&
        (counts[host] ?? 0) < maxPerHost;
  }

  /// Explicitly resume a locally deferred direct job. Native Android tasks
  /// must be resumed through FileDownloader instead of being re-enqueued.
  /// A manual resume also overrides a future in-app fallback schedule.
  static bool requeueDeferredDirect(DownloadEntry item) {
    if (item.kind != 'direct' || item.nativeQueued ||
        item.scheduledExternally ||
        !const {'paused', 'waiting'}.contains(item.status)) {
      return false;
    }
    item.status = 'waiting';
    item.autoQueue = true;
    item.retryAt = 0;
    item.scheduledAt = 0;
    return true;
  }

  /// Reconcile persisted direct-transfer metadata with Android's native task
  /// database after a process restart. Never create a second native task when
  /// the UI snapshot was saved before the enqueue callback completed.
  static void reconcileRestoredDirect(DownloadEntry item,
      {required bool nativeTaskExists}) {
    if (item.kind != 'direct' || item.scheduledExternally ||
        !const {'running', 'submitting', 'waiting', 'paused', 'verifying'}
            .contains(item.status)) {
      return;
    }
    if (item.status == 'verifying') {
      // The app may have died after receiving a native completion callback,
      // but before file/hash verification finished. Never enqueue a second
      // transfer or silently trust an unverified persisted path.
      item.autoQueue = false;
      item.nativeQueued = nativeTaskExists;
      if (!nativeTaskExists) {
        item.status = 'error';
        item.error = 'verificationFailed';
      }
      // When the native task exists, the repository re-runs file verification.
      return;
    }
    if (nativeTaskExists) {
      item.nativeQueued = true;
      item.autoQueue = false;
      if (item.status == 'submitting') item.status = 'waiting';
      return;
    }
    if (item.nativeQueued || item.status == 'running') {
      // A missing native task is not proof that a partial file is reusable.
      // Require an explicit retry instead of silently restarting the transfer.
      item.nativeQueued = false;
      item.autoQueue = false;
      item.status = 'error';
      item.error = 'nativeMissing';
    } else if (item.status == 'submitting') {
      // Preserve the previous safe recovery behavior when no native task was
      // ever registered: the original queued request may be submitted.
      item.status = 'waiting';
      item.autoQueue = true;
    }
  }

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
    // Recognize HTTP/1.1, HTTP/2 and HTTP/3 status lines as well as
    // extractor-style errors; do not mistake stale ranges for network outages.
    final codes = RegExp(
      r'\b(?:http(?:/\d+(?:\.\d+)?)?(?:\s+(?:error|status(?:\s+code)?))?|status(?:\s+code)?)\s*[:=]?\s*(\d{3})\b',
    ).allMatches(text).map((match) => int.parse(match.group(1)!)).toSet();
    // A stale partial download (412/416) needs an explicit fresh request;
    // automatically retrying the same range can repeatedly corrupt a resume.
    if (codes.any((code) => const {400, 401, 403, 404, 410, 412, 416, 451}.contains(code)) ||
        RegExp(r'\b(drm|widevine)\b|login required|sign in|private video|unsupported url|precondition failed|range not satisfiable|content[- ]range (?:mismatch|invalid)|(?:etag|checksum|hash) mismatch|no space left|disk full|enospc').hasMatch(text)) {
      return false;
    }
    // An explicit HTTP status is more authoritative than incidental socket
    // text in an error message. Never retry redirects, successful responses,
    // or permanent 4xx/5xx failures simply because they mention a timeout.
    // This also prevents a transient status from masking a later fatal one.
    const retryableHttpCodes = <int>{408, 425, 429, 500, 502, 503, 504};
    if (codes.any((code) => !retryableHttpCodes.contains(code))) {
      return false;
    }
    if (codes.isNotEmpty) return true;
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

  /// Honor explicit server backoff for HTTP 429/503 extractor failures.
  /// A Retry-After value may be seconds or an RFC 7231 HTTP-date. Never
  /// retry earlier than the existing exponential delay, and decline automatic
  /// retries for delays beyond 30 days rather than violating the server hint.
  /// Other statuses and malformed hints retain the existing retry policy.
  static Duration? retryDelayForFailure(String failure, int attempt,
      {DateTime? now}) {
    final fallback = retryDelay(attempt);
    final rateLimited = RegExp(
      r'\b(?:http(?:/\d+(?:\.\d+)?)?(?:\s+(?:error|status(?:\s+code)?))?|status(?:\s+code)?)\s*[:=]?\s*(?:429|503)\b',
      caseSensitive: false,
    ).hasMatch(failure);
    if (!rateLimited) return fallback;
    final header = RegExp(r'\bretry-after\s*:\s*([^\r\n]+)',
        caseSensitive: false).firstMatch(failure);
    if (header == null) return fallback;
    final value = header.group(1)!.trim();
    Duration requested;
    final secondsMatch = RegExp(r'^(\d+)(?=\s|$|[;,)])').firstMatch(value);
    if (secondsMatch != null) {
      // Some HTTP clients join repeated Retry-After headers with commas.
      // Never honor only the first (possibly shorter) delay: that could
      // retry before the server's longer backoff has elapsed.
      final values = value.contains(',')
          ? value.split(',').map((part) => part.trim()).toList()
          : <String>[secondsMatch.group(1)!];
      if (values.any((part) => !RegExp(r'^\d+$').hasMatch(part))) {
        return null; // Ambiguous combined delay: require a manual retry.
      }
      var longestSeconds = 0;
      for (final part in values) {
        final seconds = int.tryParse(part);
        if (seconds == null ||
            seconds > const Duration(days: 30).inSeconds) {
          return null;
        }
        if (seconds > longestSeconds) longestSeconds = seconds;
      }
      requested = Duration(seconds: longestSeconds);
    } else {
      final dateMatch = RegExp(
        r'^[A-Za-z]{3},\s+\d{1,2}\s+[A-Za-z]{3}\s+\d{4}\s+\d{2}:\d{2}:\d{2}\s+GMT\b',
        caseSensitive: false,
      ).firstMatch(value);
      if (dateMatch == null) return fallback;
      try {
        requested = HttpDate.parse(dateMatch.group(0)!)
            .difference(now ?? DateTime.now());
      } catch (_) {
        return fallback;
      }
    }
    if (requested > const Duration(days: 30)) return null;
    return requested > fallback ? requested : fallback;
  }

  static bool shouldRetry(String failure, int attempts,
      {bool enabled = true}) => enabled && attempts >= 0 && attempts < 3 && networkTransient(failure);
}
