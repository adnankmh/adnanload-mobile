/// Shared, filename-only search normalization for Downloads and Files.
///
/// This deliberately never rewrites URLs or signed query parameters. A query
/// made solely of removed diacritics must not match every stored filename.
class FilenameSearch {
  FilenameSearch._();

  static String _fold(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي');

  static bool contains(String filename, String query) {
    final needle = _fold(query.trim());
    return needle.isNotEmpty && _fold(filename).contains(needle);
  }
}
