/// Extracts the URL column from a UTF-8 CSV or tab-separated link list.
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

  /// Excel and regional exports may use semicolons or tabs instead of commas.
  /// Select an alternate dialect only for a recognizable URL heading or a
  /// URL in a later column. Signed URLs must not be split on punctuation.
  static String _detectDelimiter(String csv) {
    var quoted = false;
    var commas = 0;
    var semicolons = 0;
    var tabs = 0;
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
      if (!quoted && (char == '\r' || char == '\n')) break;
      firstRecord.write(char);
      if (!quoted) {
        if (char == ',') commas++;
        if (char == ';') semicolons++;
        if (char == '\t') tabs++;
      }
    }
    // Single-column CSV exports may have a URL heading (or a plain first
    // URL) followed by signed links containing literal commas in their query.
    // The first record alone has no delimiter, so the normal comma parser
    // would silently truncate *later* signed links. Only choose URL-per-line
    // mode when every subsequent nonempty record is an unquoted HTTP(S) URL
    // and any commas occur after its query marker. Explicit multi-column
    // headers and quoted CSV/TSV records retain the standard CSV parser.
    final firstLine = firstRecord.toString().trim();
    final normalizedFirst = firstLine.toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'), '',
    );
    const singleUrlHeaders = <String>{
      'url', 'link', 'downloadurl', 'downloadlink',
      'fileurl', 'filelink', 'sourceurl', 'sourcelink',
      'الرابط', 'رابطالتحميل', 'رابطالتنزيل', 'رابطالملف',
    };
    if (commas == 0 && semicolons == 0 && tabs == 0 &&
        !firstLine.contains('"') &&
        (singleUrlHeaders.contains(normalizedFirst) ||
            _looksLikeHttpUrl(firstLine))) {
      final lines = csv.split(RegExp(r'\r\n|\r|\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (lines.length > 1) {
        final later = lines.skip(1);
        final hasSignedComma = later.any((line) {
          final comma = line.indexOf(',');
          return comma >= 0 && line.indexOf('?') >= 0 &&
              comma > line.indexOf('?');
        });
        final allSingleUrls = later.every((line) {
          if (line.contains('"') || line.contains('\t')) return false;
          final comma = line.indexOf(',');
          final query = line.indexOf('?');
          return _looksLikeHttpUrl(line) &&
              (comma < 0 || (query >= 0 && comma > query));
        });
        if (hasSignedComma && allSingleUrls) {
          return '\u0000'; // No separator: preserve complete signed URLs.
        }
      }
    }

    // A line-per-link export can contain unquoted commas inside signed
    // query values. Without a header or another explicit delimiter, treating
    // these as CSV columns would silently truncate authorization tokens.
    // Preserve each complete HTTP(S) URL as a single field. A genuine CSV
    // with an explicit URL header still uses the normal comma dialect.
    if (commas > 0 && semicolons == 0 && tabs == 0) {
      final firstLine = firstRecord.toString().trim();
      final query = firstLine.indexOf('?');
      final comma = firstLine.indexOf(',');
      if (query >= 0 && comma > query &&
          !firstLine.contains('"') && _looksLikeHttpUrl(firstLine)) {
        return '\u0000'; // Sentinel absent from validated public URLs.
      }
    }
    if (semicolons == 0 && tabs == 0) return ',';

    const headings = <String>{
      'downloadurl', 'downloadlink', 'fileurl', 'filelink',
      'url', 'link', 'sourceurl', 'sourcelink',
      'رابطالتحميل', 'رابطالتنزيل', 'رابطالملف', 'الرابط',
    };
    bool hasHeader(String delimiter) {
      final cells = firstRecord.toString().split(delimiter);
      return cells.length > 1 && cells.any((cell) => headings.contains(
        cell.trim().replaceAll('"', '').toLowerCase().replaceAll(
          RegExp(r'[\s_-]+'), '',
        ),
      ));
    }

    // A comma inside a semicolon CSV's descriptive heading (e.g.
    // "Title, description;Download URL") is not evidence of comma CSV.
    // Prefer an unambiguous recognized heading over punctuation counts.
    // When both dialects appear plausible, retain the legacy comma default.
    final semicolonHeader = semicolons > 0 && hasHeader(';');
    final commaHeader = commas > 0 && hasHeader(',');
    final tabHeader = tabs > 0 && hasHeader('\t');
    // A tab-separated header can include commas/semicolons in a description.
    // Recognized comma/semicolon headers retain their existing precedence.
    if (tabHeader && !commaHeader && !semicolonHeader) return '\t';
    if (semicolonHeader && !commaHeader) return ';';
    if (commaHeader) return ',';
    if (tabHeader) return '\t';

    // Headerless TSV: the HTTP(S) URL can be the first or a later column.
    // Only unquoted tabs count as delimiters; preserve signed URL punctuation.
    if (tabs > 0 && firstRecord.toString().split('\t').any(
        (cell) => _looksLikeHttpUrl(cell.trim().replaceAll('"', '')))) {
      return '\t';
    }
    if (commas > 0) return ',';
    if (semicolonHeader) return ';';

    final cells = firstRecord.toString().split(';');
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
