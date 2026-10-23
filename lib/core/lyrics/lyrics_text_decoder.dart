import 'dart:convert';
import 'dart:typed_data';

/// Decodes the bytes of a lyrics file: UTF-8 with or without BOM, UTF-16
/// LE or BE with BOM, and Latin-1 when the bytes are not valid UTF-8 (old
/// `.lrc` files). Never throws.
String decodeLyricsBytes(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _utf16(bytes, 2, Endian.little);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _utf16(bytes, 2, Endian.big);
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

/// UTF-16 from [start]; a trailing odd byte is ignored and unpaired
/// surrogates become U+FFFD (as `String.fromCharCodes` keeps them, they are
/// replaced explicitly).
String _utf16(Uint8List bytes, int start, Endian endian) {
  final data = ByteData.sublistView(bytes);
  final units = <int>[];
  for (var i = start; i + 1 < bytes.length; i += 2) {
    units.add(data.getUint16(i, endian));
  }
  final out = StringBuffer();
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (i + 1 < units.length &&
          units[i + 1] >= 0xDC00 &&
          units[i + 1] <= 0xDFFF) {
        out.writeCharCode(
          0x10000 + ((unit - 0xD800) << 10) + (units[i + 1] - 0xDC00),
        );
        i++;
      } else {
        out.writeCharCode(0xFFFD);
      }
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      out.writeCharCode(0xFFFD);
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}
