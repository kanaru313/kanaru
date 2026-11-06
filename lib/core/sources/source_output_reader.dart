/// Checks of what a source plugin's scripts output: the limits and helpers
/// the `search.js` and `stream.js` readers share, and both readers.
library;

import 'dart:convert';

import '../lyrics/plugins/plugin_output_reader.dart' show PluginOutputException;

export '../lyrics/plugins/plugin_output_reader.dart' show PluginOutputException;
export 'source_search_output_reader.dart';
export 'source_stream_output_reader.dart';

/// Largest `next` of a page and largest stream `url`, in UTF-8 bytes.
const maxSourceTokenBytes = 8 * 1024;

/// The decoded output JSON of a source script. Throws
/// [PluginOutputException] when it is not JSON.
Object? decodeSourceOutput(String json) {
  try {
    return jsonDecode(json);
  } on FormatException {
    throw const PluginOutputException('the output is not valid JSON');
  }
}

/// [value] as an integer above 0 (a whole double such as `5.0` counts), else
/// null.
int? sourcePositiveInt(Object? value) {
  final int number;
  if (value is int) {
    number = value;
  } else if (value is double &&
      value.isFinite &&
      value == value.truncate() &&
      value.abs() < 9007199254740992.0) {
    number = value.toInt();
  } else {
    return null;
  }
  return number > 0 ? number : null;
}

/// The UTF-8 length of [text], or its UTF-16 length when that cannot pass
/// [maxSourceTokenBytes] either way (cheaper, same verdict).
int sourceTokenBytes(String text) {
  // A UTF-16 unit is at least one byte and at most three.
  if (text.length * 3 <= maxSourceTokenBytes) return text.length;
  return utf8.encode(text).length;
}
