/// Extracts the URL column from an RFC 4180-style UTF-8 CSV link list.
///
/// Input decoding and the 1 MiB file limit are handled by BatchTextImport.
/// All extracted links still pass through BatchLinks / UrlGuard before use.
class BatchCsvImport {
  static String extractUrls(String csv) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    var afterQuote = false;

    void finishField() {
      row.add(field.toString());
      field = StringBuffer();
      afterQuote = false;
    }

    void finishRow() {
      finishField();
      if (row.any((cell) => cell.trim().isNotEmpty)) {
        rows.add(row);
      }
      row = <String>[];
    }

    final delimiter = _detectDelimiter(csv);

    for (var i = 0; i < csv.length; i++) {
      final char = csv[i];
      if (quoted) {
        if (char == '"') {
          if (i + 1 < csv.length && csv[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
            afterQuote = true;
          }
        } else {
          field.write(char);
        }
      } else if (afterQuote && char != delimiter && char != '\r' && char != '\n') {
        // RFC 4180: a closing quote must be followed by a delimiter or
        // record end. Ignore only harmless formatting whitespace; never
        // silently append text to a previously quoted URL.
        if (char != ' ' && char != '\t') {
          throw const FormatException('Malformed CSV quoting');
        }
      } else if (char == '"' && field.length == 0) {
        quoted = true;
      } else if (char == '"') {
        throw const FormatException('Malformed CSV quoting');
      } else if (char == delimiter) {
        finishField();
      } else if (char == '\r' || char == '\n') {
        finishRow();
        if (char == '\r' && i + 1 < csv.length && csv[i + 1] == '\n') {
          i++;
        }
      } else {
        field.write(char);
      }
    }
    if (quoted) throw const FormatException('Unterminated CSV field');
    if (field.length > 0 || row.isNotEmpty) finishRow();
    if (rows.isEmpty) throw const FormatException('CSV file is empty');

    final first = rows.first;
    // An export can contain both a page/source URL and the actual download
    // URL. Prefer an explicitly named download column regardless of order;
    // otherwise the first URL-looking column can enqueue the wrong resource.
    // Retain generic and source-only headers for existing CSV files.
    const headerPriorities = <Set<String>>[
      {'downloadurl', 'downloadlink', 'رابطالتحميل', 'رابطالتنزيل'},
      {'fileurl', 'filelink', 'رابطالملف'},
      {'url', 'link', 'الرابط'},
      {'sourceurl', 'sourcelink'},
    ];
    final normalizedHeaders = first.map((cell) =>
        cell.trim().toLowerCase().replaceAll(
          RegExp(r'[\s_-]+'), '',
        )).toList();
    var headerIndex = -1;
    for (final names in headerPriorities) {
      headerIndex = normalizedHeaders.indexWhere(names.contains);
      if (headerIndex >= 0) break;
    }
    var column = headerIndex < 0 ? 0 : headerIndex;
    var start = headerIndex < 0 ? 0 : 1;
    if (headerIndex < 0) {
      // Headerless CSVs may put the URL after a title or description.
      // Only infer the column here; BatchLinks/UrlGuard still validate every URL.
      final sample = rows.take(12).toList();
      final width = sample.fold<int>(0, (max, values) =>
          values.length > max ? values.length : max);
      var bestCount = 0;
      for (var index = 0; index < width; index++) {
        final count = sample.where((values) =>
            index < values.length && _looksLikeHttpUrl(values[index])).length;
        if (count > bestCount) {
          bestCount = count;
          column = index;
        }
      }
      // Skip an unrecognized heading row without losing headerless first links.
      if (bestCount > 0 &&
          (column >= first.length || !_looksLikeHttpUrl(first[column]))) {
        start = 1;
      }
    }
    final urls = <String>[];
    for (final values in rows.skip(start)) {
      if (column < values.length && values[column].trim().isNotEmpty) {
        urls.add(values[column].trim());
      }
    }
    return urls.join('\n');
  }

  /// Excel and regional exports often use semicolons instead of commas.
  /// Only select that dialect when the first record supplies a recognizable
  /// URL heading or a URL in a later column. A single signed URL containing
  /// semicolons must remain intact rather than being mistaken for a CSV row.
  static String _detectDelimiter(String csv) {
    var quoted = false;
    var commas = 0;
    var semicolons = 0;
    final firstRecord = StringBuffer();
    for (var i = 0; i < csv.length; i++) {
      final char = csv[i];
      if (char == '"') {
        if (quoted && i + 1 < csv.length && csv[i + 1] == '"') {
          firstRecord.write('""');
          i++;
          continue;
        }
        quoted = !quoted;
      }
      if (!quoted && (char == '\\r' || char == '\\n')) break;
      firstRecord.write(char);
      if (!quoted) {
        if (char == ',') commas++;
        if (char == ';') semicolons++;
      }
    }
    if (commas > 0 || semicolons == 0) return ',';

    final cells = firstRecord.toString().split(';');
    const headings = <String>{
      'downloadurl', 'downloadlink', 'fileurl', 'filelink',
      'url', 'link', 'sourceurl', 'sourcelink',
      'رابطالتحميل', 'رابطالتنزيل', 'رابطالملف', 'الرابط',
    };
    final recognizedHeader = cells.any((cell) => headings.contains(
      cell.trim().replaceAll('"', '').toLowerCase().replaceAll(
        RegExp(r'[\\s_-]+'), '',
      ),
    ));
    if (recognizedHeader) return ';';
    // Headerless lists with a title followed by a URL are unambiguous.
    // Do not split a URL-first record just because its signed query contains
    // semicolons: those bytes may be part of a one-time authorization token.
    if (cells.skip(1).any((cell) =>
        _looksLikeHttpUrl(cell.trim().replaceAll('"', '')))) return ';';
    return ',';
  }

  static bool _looksLikeHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && uri.hasAuthority && uri.host.isNotEmpty &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
