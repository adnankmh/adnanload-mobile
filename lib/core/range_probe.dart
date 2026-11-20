import 'dart:io';

import 'url_guard.dart';

/// Conservative preflight for native parallel downloads.
///
/// A one-byte 206 response alone is not sufficient evidence that a server can
/// safely serve independent byte ranges of the same immutable representation.
/// On uncertainty, use the native downloader's single-stream fallback.
class RangeProbe {
  RangeProbe._();

  static final RegExp _contentRange =
      RegExp(r'^bytes 0-0/([1-9][0-9]*)$');
  static final RegExp _strongEtag =
      RegExp(r'^"[^"\x00-\x1F\x7F]+"$');

  /// Pure header check so malformed and incomplete responses can be tested.
  static bool supportsParallelResponse({
    required int statusCode,
    required String? acceptRanges,
    required String? etag,
    required String? contentRange,
    required int contentLength,
    String? contentEncoding,
    String? contentType,
    String? vary,
  }) {
    if (statusCode != HttpStatus.partialContent || contentLength != 1) {
      return false;
    }
    if (acceptRanges?.trim().toLowerCase() != 'bytes') return false;
    if (etag == null || !_strongEtag.hasMatch(etag.trim())) return false;
    // Multipart byte ranges are not a single raw byte representation.
    if (contentType != null &&
        contentType.split(';').first.trim().toLowerCase() ==
            'multipart/byteranges') return false;
    // Vary means the representation may depend on request headers. The
    // native downloader cannot guarantee it repeats every probe header, so
    // even a strong ETag cannot prove all segments describe the same bytes.
    // Fail closed to the existing single-stream path for any Vary field.
    if (vary != null && vary.trim().isNotEmpty) return false;
    final encoding = contentEncoding?.trim().toLowerCase();
    if (encoding != null && encoding.isNotEmpty && encoding != 'identity') {
      return false;
    }
    final match = _contentRange.firstMatch(contentRange?.trim() ?? '');
    final total = int.tryParse(match?.group(1) ?? '');
    return total != null && total > 1;
  }

  /// A server can advertise a valid one-byte range while returning no body.
  /// Read exactly one byte before enabling segmented downloads; malformed,
  /// truncated or stalled responses must use the single-stream fallback.
  static Future<bool> verifyProbeResponse(HttpClientResponse response) async {
    try {
      if (!supportsParallelResponse(
        statusCode: response.statusCode,
        acceptRanges: response.headers.value('accept-ranges'),
        etag: response.headers.value('etag'),
        contentRange: response.headers.value('content-range'),
        contentLength: response.contentLength,
        contentEncoding: response.headers.value('content-encoding'),
        contentType: response.headers.value('content-type'),
        vary: response.headers['vary']?.join(','),
      )) {
        return false;
      }
      final count = await response.fold<int>(0, (count, bytes) {
        final next = count + bytes.length;
        if (next > 1) {
          throw const FormatException('Range probe body exceeds one byte');
        }
        return next;
      }).timeout(const Duration(seconds: 9));
      return count == 1;
    } catch (_) {
      return false;
    }
  }

  /// Some CDN URLs use short-lived or single-use signed query parameters.
  /// A separate range GET can consume their authorization before the native
  /// downloader starts. Prefer a single native stream without preflight.
  ///
  /// This is intentionally conservative and only examines parameter *names*:
  /// opaque signed values must never be logged or modified.
  static bool avoidPreflightForSignedUrl(Uri url) {
    const signedKeys = <String>{
      'signature', 'sig', 'token', 'accesstoken', 'authorization',
      'auth', 'jwt', 'expires', 'policy', 'keypairid',
      'awsaccesskeyid', 'xamzsignature', 'xamzcredential',
      'xamzsecuritytoken', 'xgoogsignature', 'xgoogcredential',
      'googleaccessid',
      // AWS SigV4 and Google V4 query signing metadata. Even when a CDN
      // strips the signature field, a speculative GET can spend a short-lived
      // authorization grant before Android starts the actual download.
      'xamzalgorithm', 'xamzdate', 'xamzexpires', 'xamzsignedheaders',
      'xgoogalgorithm', 'xgoogdate', 'xgoogexpires',
      'xgoogsignedheaders',
      // Akamai and other CDNs use opaque token/HMAC parameter names.
      'hdnts', 'hdntl', 'authkey', 'hmac',
    };
    for (final name in url.queryParameters.keys) {
      final normalized = name.toLowerCase().replaceAll(RegExp(r'[-_]'), '');
      if (signedKeys.contains(normalized)) return true;
    }
    return false;
  }

  /// Probe only validated public HTTP(S) URLs; never follow probe redirects.
  /// This does not change the native downloader's own retry/resume handling.
  static Future<bool> supportsSafeParallelDownload(Uri url) async {
    if (UrlGuard.validate(url.toString()) == null ||
        avoidPreflightForSignedUrl(url)) return false;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..autoUncompress = false;
    try {
      final request = await client.getUrl(url)
          .timeout(const Duration(seconds: 9));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      request.headers.set('accept-encoding', 'identity');
      final response = await request.close()
          .timeout(const Duration(seconds: 9));
      return await verifyProbeResponse(response);
    } catch (_) {
      return false;
    } finally {
      // Never drain an untrusted response body of unbounded size.
      client.close(force: true);
    }
  }
}
