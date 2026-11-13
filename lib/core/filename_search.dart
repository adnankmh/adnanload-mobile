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
      .replaceAll('ى', 'ي')
      // Arabic-Indic and Eastern Arabic-Indic numerals represent the same
      // decimal digits as ASCII. Fold filenames and search terms only:
      // signed URL queries must remain literal and byte-for-byte unchanged.
      .replaceAllMapped(RegExp(r'[\u0660-\u0669\u06F0-\u06F9]'), (match) {
        final digit = match.group(0)!.codeUnitAt(0);
        final zero = digit >= 0x06F0 ? 0x06F0 : 0x0660;
        return String.fromCharCode(0x30 + digit - zero);
      });

  static bool contains(String filename, String query) {
    final needle = _fold(query).trim();
    return needle.isNotEmpty && _fold(filename).contains(needle);
  }
}
