import 'dart:io';

import '../models/download_entry.dart';
import 'url_guard.dart';

/// Deterministic queue policy. Never bypasses the Android OS scheduler.
class TransferPolicy {
  /// Extract status labels from log messages, not URL query parameters.
  /// A URL such as ?status=404&http=503 must not suppress a legitimate
  /// socket retry or create a false rate-limit delay. Preserve standalone
  /// 'status=503' and 'HTTP=429' formats from native/extractor errors.
  static final RegExp _httpStatus = RegExp(
    r'(?:^|[\s:;,(])(?:http(?:/\d+(?:\.\d+)?)?(?:\s+(?:error|status(?:\s+code)?))?|status(?:\s+code)?)\s*[:=]?\s*(\d{3})\b',
    caseSensitive: false,
  );

  // URL paths and queries may contain ';status=404' or ',HTTP=503'.
  // Strip embedded URLs before interpreting response-status tokens.
  static final RegExp _urlInFailure = RegExp(
    r'https?://[^\s<>]+',
    caseSensitive: false,
  );

  static Set<int> _statusCodes(String failure) {
    final logText = failure.replaceAll(_urlInFailure, ' ');
    return _httpStatus.allMatches(logText)
        .map((match) => int.parse(match.group(1)!))
        .toSet();
  }

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

  /// The queue takes a snapshot before awaiting storage checks. Revalidate
  /// immediately before native submission so a later pause, cancel or schedule
  /// edit cannot start work from that stale snapshot.
  static bool readyToDispatch(DownloadEntry item, int now) =>
      item.status == 'waiting' && item.autoQueue &&
      !item.scheduledExternally &&
      !(item.kind == 'direct' && item.nativeQueued) &&
      (item.scheduledAt == 0 || item.scheduledAt <= now) &&
      (item.retryAt == 0 || item.retryAt <= now);

  /// A direct task must still be in the same submitting state after each
  /// asynchronous native lookup, notification request and range probe.
  /// Cancellation revokes permission to enqueue even before Android finishes
  /// canceling an already-existing task.
  static bool directSubmissionStillAllowed(DownloadEntry item,
      {required bool isTracked}) =>
      isTracked && item.kind == 'direct' &&
      item.status == 'submitting' && !item.scheduledExternally &&
      !item.nativeQueued;

  /// Mark cancellation synchronously before awaiting platform cleanup.
  /// Otherwise an in-flight range probe or native enqueue can revive the job.
  static void markCanceled(DownloadEntry item) {
    item.status = 'canceled';
    item.autoQueue = false;
    item.nativeQueued = false;
    item.retryAt = 0;
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
    // URLs are diagnostic context, not error messages. Their paths or signed
    // queries can contain words such as 'timeout', 'drm' or 'login required';
    // those must neither invent a retry nor suppress a real socket retry.
    final text = failure.replaceAll(_urlInFailure, ' ').toLowerCase();
    // Extractors commonly report "HTTP Error 429", while native clients can
    // report "status code: 503". Plain substring matching missed both forms.
    // Recognize HTTP/1.1, HTTP/2 and HTTP/3 status lines as well as
    // extractor-style errors; do not mistake stale ranges for network outages.
    final codes = _statusCodes(text);
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
    final rateLimited = _statusCodes(failure).any(
      (code) => code == 429 || code == 503,
    );
    if (!rateLimited) return fallback;
    // Extractors and HTTP clients may report multiple Retry-After lines.
    // Using only the first can retry before a later, longer server deadline.
    // A URL query such as ?retry-after:3600 is not a server header. Ignore
    // URL text while retaining real multiline and inline Retry-After hints.
    final headers = RegExp(
      r'\bretry-after[ \t]*:[ \t]*([^\r\n]*)',
      caseSensitive: false,
    ).allMatches(failure.replaceAll(_urlInFailure, ' ')).toList();
    if (headers.isEmpty) return fallback;
    // Malformed or excessive header sets require an explicit manual retry.
    if (headers.length > 16) return null;
    var longest = fallback;
    for (final header in headers) {
      final value = header.group(1)!.trim();
      if (value.isEmpty) return null;
      Duration requested;
      if (RegExp(r'^\d').hasMatch(value)) {
        // A numeric hint must be a complete number or a comma-separated
        // numeric list; never accept a prefix such as "600 seconds".
        final values = value.split(',').map((part) => part.trim()).toList();
        if (values.any((part) => !RegExp(r'^\d+$').hasMatch(part))) {
          return null;
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
          r'^[A-Za-z]{3},\s+\d{1,2}\s+[A-Za-z]{3}\s+\d{4}\s+\d{2}:\d{2}:\d{2}\s+GMT',
          caseSensitive: false,
        ).firstMatch(value);
        // Preserve the previous fallback for a single unrecognized hint,
        // but never ignore an ambiguous member of a repeated header set.
        if (dateMatch == null) {
          return headers.length == 1 ? fallback : null;
        }
        if (dateMatch.end != value.length) return null;
        try {
          requested = HttpDate.parse(value)
              .difference(now ?? DateTime.now());
        } catch (_) {
          return headers.length == 1 ? fallback : null;
        }
      }
      if (requested > const Duration(days: 30)) return null;
      if (requested > longest) longest = requested;
    }
    return longest;
  }

  static bool shouldRetry(String failure, int attempts,
      {bool enabled = true}) => enabled && attempts >= 0 && attempts < 3 && networkTransient(failure);
}
