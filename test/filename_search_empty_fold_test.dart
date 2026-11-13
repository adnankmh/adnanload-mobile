import 'package:adnanload_mobile/core/filename_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marks separated by whitespace do not match unrelated filenames', () {
    for (final query in ['\u064E \u0640', '\u0670\t\u064E']) {
      expect(FilenameSearch.contains('my report.pdf', query), isFalse);
    }
  });

  test('trims whitespace exposed by removing outer Arabic marks', () {
    expect(FilenameSearch.contains('Report.pdf', '\u064E Report.pdf \u0640'),
        isTrue);
    expect(FilenameSearch.contains('my report.pdf', 'my report'), isTrue);
    expect(FilenameSearch.contains('my report.pdf', 'my  report'), isFalse);
  });
}
