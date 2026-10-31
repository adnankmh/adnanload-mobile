import 'dart:io';

import 'package:adnanload_mobile/core/range_probe.dart';
import 'package:flutter_test/flutter_test.dart';

bool safe({
  int statusCode = HttpStatus.partialContent,
  String? acceptRanges = 'bytes',
  String? etag = '"v1"',
  String? contentRange = 'bytes 0-0/4096',
  int contentLength = 1,
  String? contentEncoding,
}) => RangeProbe.supportsParallelResponse(
  statusCode: statusCode,
  acceptRanges: acceptRanges,
  etag: etag,
  contentRange: contentRange,
  contentLength: contentLength,
  contentEncoding: contentEncoding,
);

/// Exercise the real HTTP response stream without weakening URLGuard's
/// public-host restriction in supportsSafeParallelDownload.
Future<bool> probeLocalResponse({
  List<int> body = const [0x41],
  int declaredLength = 1,
  String contentRange = 'bytes 0-0/4096',
  String etag = '"v1"',
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final reply = request.response;
    reply.statusCode = HttpStatus.partialContent;
    reply.headers.set('accept-ranges', 'bytes');
    reply.headers.set('etag', etag);
    reply.headers.set('content-range', contentRange);
    reply.contentLength = declaredLength;
    if (body.isNotEmpty) reply.add(body);
    try { await reply.close(); } catch (_) { /* intentional truncated test response */ }
  });
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/probe'));
    final response = await request.close();
    return await RangeProbe.verifyProbeResponse(response);
  } finally {
    client.close(force: true);
    await server.close(force: true);
  }
}

void main() {
  test('strong ETag and exact one-byte range permit parallel transfer', () {
    expect(safe(), isTrue);
    expect(safe(acceptRanges: ' Bytes ', etag: ' "v2" '), isTrue);
    expect(safe(contentRange: 'bytes 0-0/2'), isTrue);
  });

  test('full responses, redirects and invalid ranges fall back', () {
    for (final status in [200, 301, 302, 307, 308, 416, 500]) {
      expect(safe(statusCode: status), isFalse, reason: '$status');
    }
  });

  test('missing or weak ETags cannot validate segmented downloads', () {
    for (final value in <String?>[null, '', 'W/"v1"', 'v1', '""']) {
      expect(safe(etag: value), isFalse, reason: '$value');
    }
  });

  test('malformed Content-Range and unknown total size fall back', () {
    for (final value in <String?>[
      null, '', 'bytes */4096', 'bytes 0-1/4096',
      'bytes 1-1/4096', 'bytes 0-0/*', 'bytes 0-0/1',
      'bytes 0-0/0', 'bytes 0-0/not-a-number',
    ]) {
      expect(safe(contentRange: value), isFalse, reason: '$value');
    }
  });

  test('range capability and response length must both be explicit', () {
    for (final value in <String?>[null, '', 'none', 'bytes, none']) {
      expect(safe(acceptRanges: value), isFalse, reason: '$value');
    }
    expect(safe(contentLength: -1), isFalse);
    expect(safe(contentLength: 2), isFalse);
  });

  test('compressed byte representations cannot be segmented', () {
    expect(safe(contentEncoding: 'gzip'), isFalse);
    expect(safe(contentEncoding: 'br'), isFalse);
    expect(safe(contentEncoding: 'identity'), isTrue);
  });

  test('real HTTP 206 response needs the advertised single body byte', () async {
    expect(await probeLocalResponse(), isTrue);
    expect(await probeLocalResponse(body: const []), isFalse);
    expect(await probeLocalResponse(body: const [], declaredLength: 0), isFalse);
  });

  test('valid body does not override unsafe range or ETag headers', () async {
    expect(await probeLocalResponse(contentRange: 'bytes 0-1/4096'), isFalse);
    expect(await probeLocalResponse(etag: 'W/"v1"'), isFalse);
  });

  test('unsafe URL never triggers a preflight request', () async {
    expect(await RangeProbe.supportsSafeParallelDownload(
      Uri.parse('http://127.0.0.1/file')), isFalse);
    expect(await RangeProbe.supportsSafeParallelDownload(
      Uri.parse('file:///etc/passwd')), isFalse);
  });
}
