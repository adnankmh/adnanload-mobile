import 'dart:async';
import 'dart:io';

import 'package:adnanload_mobile/core/range_probe.dart';
import 'package:flutter_test/flutter_test.dart';

bool _safe({String? vary}) => RangeProbe.supportsParallelResponse(
  statusCode: HttpStatus.partialContent,
  acceptRanges: 'bytes',
  etag: '"immutable-v1"',
  contentRange: 'bytes 0-0/8192',
  contentLength: 1,
  vary: vary,
);

class _Headers implements HttpHeaders {
  _Headers({this.vary, this.duplicateEtag = false});

  final List<String>? vary;
  final bool duplicateEtag;

  @override
  String? value(String name) {
    if (name.toLowerCase() == 'etag' && duplicateEtag) {
      throw const HttpException('Multiple ETag headers');
    }
    return <String, String>{
      'accept-ranges': 'bytes',
      'etag': '"immutable-v1"',
      'content-range': 'bytes 0-0/8192',
    }[name.toLowerCase()];
  }

  @override
  List<String>? operator [](String name) =>
      name.toLowerCase() == 'vary' ? vary : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends StreamView<List<int>> implements HttpClientResponse {
  _Response(this.headers) : super(Stream<List<int>>.value(const [0x41]));

  @override
  final HttpHeaders headers;

  @override
  int get statusCode => HttpStatus.partialContent;

  @override
  int get contentLength => 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('unsafe Vary fields require single-stream fallback', () {
    for (final vary in <String>[
      '*',
      'Accept-Encoding',
      'COOKIE',
      'Authorization',
      'User-Agent',
      'Origin, Accept-Encoding',
      'origin,\tCookie',
    ]) {
      expect(_safe(vary: vary), isFalse, reason: vary);
    }
  });

  test('unrelated Vary fields preserve parallel capability', () {
    expect(_safe(), isTrue);
    expect(_safe(vary: ''), isTrue);
    expect(_safe(vary: 'Origin'), isTrue);
    expect(_safe(vary: 'Origin, Accept-Language'), isTrue);
  });

  test('repeated Vary response headers are combined safely', () async {
    final response = _Response(_Headers(
      vary: const ['Origin', 'Accept-Encoding'],
    ));
    expect(await RangeProbe.verifyProbeResponse(response), isFalse);
  });

  test('harmless Vary response header keeps valid one-byte probe', () async {
    final response = _Response(_Headers(vary: const ['Origin']));
    expect(await RangeProbe.verifyProbeResponse(response), isTrue);
  });

  test('duplicate or malformed response headers fail closed', () async {
    final response = _Response(_Headers(duplicateEtag: true));
    expect(await RangeProbe.verifyProbeResponse(response), isFalse);
  });
}
