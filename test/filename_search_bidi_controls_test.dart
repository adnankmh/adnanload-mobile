import 'package:adnanload_mobile/core/filename_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invisible Arabic bidi controls do not block filename matches', () {
    expect(FilenameSearch.contains('تقرير ٢٠٢٦.pdf', '\u200Fتقرير 2026'), isTrue);
    expect(FilenameSearch.contains('report.pdf', 're\u200Eport'), isTrue);
    expect(FilenameSearch.contains('report.pdf', '\u2067report\u2069'), isTrue);
    expect(FilenameSearch.contains('تقرير.pdf', '\u061Cتقرير'), isTrue);
  });

  test('queries containing only bidi controls never match all files', () {
    for (final query in ['\u200F', '\u061C\u200E', '\u2067\u2069']) {
      expect(FilenameSearch.contains('report.pdf', query), isFalse);
    }
  });

  test('visible punctuation and internal spacing are not removed', () {
    expect(FilenameSearch.contains('report.pdf', 're-port'), isFalse);
    expect(FilenameSearch.contains('my report.pdf', 'my  report'), isFalse);
  });
}
