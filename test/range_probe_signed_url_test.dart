import 'package:adnanload_mobile/core/range_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed CDN query parameters disable speculative range GET', () {
    for (final query in [
      'X-Amz-Signature=abc&X-Amz-Expires=60',
      'X-Goog-Signature=abc',
      'Signature=abc&Key-Pair-Id=K123',
      'sig=abc&se=2026-11-04',
      'access_token=abc',
      'TOKEN=abc',
      '%58-Amz-Signature=abc',
      'AWSAccessKeyId=abc',
      'X-Amz-Security-Token=abc',
    ]) {
      final url = Uri.parse('https://cdn.example.org/file.bin?$query');
      expect(RangeProbe.avoidPreflightForSignedUrl(url), isTrue,
          reason: query);
    }
  });

  test('ordinary query strings retain parallel preflight eligibility', () {
    for (final query in [
      '',
      'page=2',
      'download=1&quality=high',
      'file=report.pdf&version=4',
    ]) {
      final url = Uri.parse('https://cdn.example.org/file.bin'
          '${query.isEmpty ? '' : '?$query'}');
      expect(RangeProbe.avoidPreflightForSignedUrl(url), isFalse,
          reason: query);
    }
  });

  test('signed links fall back before opening any network connection', () async {
    // The .invalid TLD is deliberately unresolvable; this must return
    // immediately without contacting a server or changing the signed URL.
    final signed = Uri.parse(
      'https://downloads.example.invalid/archive.zip?signature=one-time');
    expect(await RangeProbe.supportsSafeParallelDownload(signed), isFalse);
    expect(signed.queryParameters['signature'], 'one-time');
  });

  test('unrelated parameter values are not treated as auth names', () {
    final url = Uri.parse(
      'https://cdn.example.org/file?filename=token&download=signature');
    expect(RangeProbe.avoidPreflightForSignedUrl(url), isFalse);
  });
}
