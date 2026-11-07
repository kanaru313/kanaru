import 'hls_refusal.dart';

/// Parses an attribute list (RFC 8216 4.2): `NAME=value` pairs separated by
/// commas, values quoted (may hold commas) or not. Unknown attributes are
/// kept. [text] null or empty gives no attributes.
///
/// Quoted values come back without their quotes. A repeated attribute, a
/// malformed name, a missing `=`, an unterminated quote or text after a
/// closing quote → `invalid`.
Map<String, String> parseHlsAttributeList(String? text) {
  final attributes = <String, String>{};
  if (text == null) return attributes;
  final length = text.length;
  var i = 0;
  while (true) {
    i = _skipSpaces(text, i);
    if (i >= length) return attributes;
    final nameStart = i;
    while (i < length && _isNameChar(text.codeUnitAt(i))) {
      i++;
    }
    if (i == nameStart || i >= length || text[i] != '=') {
      throw const HlsRefusal(HlsRefusalKind.invalid);
    }
    final name = text.substring(nameStart, i);
    i++; // '='
    final String value;
    if (i < length && text[i] == '"') {
      final close = text.indexOf('"', i + 1);
      if (close < 0) throw const HlsRefusal(HlsRefusalKind.invalid);
      value = text.substring(i + 1, close);
      i = _skipSpaces(text, close + 1);
      if (i < length && text[i] != ',') {
        throw const HlsRefusal(HlsRefusalKind.invalid);
      }
    } else {
      var end = text.indexOf(',', i);
      if (end < 0) end = length;
      value = text.substring(i, end).trim();
      if (value.contains('"')) throw const HlsRefusal(HlsRefusalKind.invalid);
      i = end;
    }
    if (attributes.containsKey(name)) {
      throw const HlsRefusal(HlsRefusalKind.invalid);
    }
    attributes[name] = value;
    i++; // ','
  }
}

int _skipSpaces(String text, int from) {
  var i = from;
  while (i < text.length && (text[i] == ' ' || text[i] == '\t')) {
    i++;
  }
  return i;
}

/// `A-Z`, `0-9` and `-`.
bool _isNameChar(int unit) =>
    (unit >= 0x41 && unit <= 0x5A) ||
    (unit >= 0x30 && unit <= 0x39) ||
    unit == 0x2D;
