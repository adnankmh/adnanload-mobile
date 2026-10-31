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

    void finishField() {
      row.add(field.toString());
      field = StringBuffer();
    }

    void finishRow() {
      finishField();
      if (row.any((cell) => cell.trim().isNotEmpty)) {
        rows.add(row);
      }
      row = <String>[];
    }

    for (var i = 0; i < csv.length; i++) {
      final char = csv[i];
      if (quoted) {
        if (char == '"') {
          if (i + 1 < csv.length && csv[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          field.write(char);
        }
      } else if (char == '"' && field.length == 0) {
        quoted = true;
      } else if (char == '"') {
        throw const FormatException('Malformed CSV quoting');
      } else if (char == ',') {
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

    const headers = {'url', 'link', 'downloadurl', 'sourceurl', 'fileurl', 'الرابط'};
    final first = rows.first;
    final headerIndex = first.indexWhere((cell) =>
        headers.contains(cell.trim().toLowerCase().replaceAll(
          RegExp(r'[\s_-]+'), '',
        )));
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

  static bool _looksLikeHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && uri.hasAuthority && uri.host.isNotEmpty &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
