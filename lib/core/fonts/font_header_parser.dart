import 'dart:convert';
import 'dart:typed_data';

class FontHeaderParser {
  /// Accepts TrueType (0x00010000), OpenType-CFF (`OTTO`) and Apple `true`.
  /// TrueType Collections (`ttcf`) are rejected: Flutter's FontLoader cannot
  /// use them and their header layout differs.
  static bool isValidFontBytes(Uint8List bytes) {
    if (bytes.length < 12) return false;
    final b0 = bytes[0], b1 = bytes[1], b2 = bytes[2], b3 = bytes[3];
    if (b0 == 0x00 && b1 == 0x01 && b2 == 0x00 && b3 == 0x00) return true;
    if (b0 == 0x4F && b1 == 0x54 && b2 == 0x54 && b3 == 0x4F) return true; // OTTO
    if (b0 == 0x74 && b1 == 0x72 && b2 == 0x75 && b3 == 0x65) return true; // true
    return false;
  }

  /// Reads the family name from the `name` table: Name ID 16 (typographic
  /// family) first, then Name ID 1 (family). Returns null when unavailable.
  static String? extractFontName(Uint8List bytes) {
    try {
      if (!isValidFontBytes(bytes)) return null;
      final data = ByteData.sublistView(bytes);
      final numTables = data.getUint16(4);

      var nameOffset = -1;
      for (var i = 0, dir = 12; i < numTables; i++, dir += 16) {
        if (dir + 16 > bytes.length) break;
        final tag = String.fromCharCodes(bytes.sublist(dir, dir + 4));
        if (tag == 'name') {
          nameOffset = data.getUint32(dir + 8);
          break;
        }
      }
      if (nameOffset < 0 || nameOffset + 6 > bytes.length) return null;

      final count = data.getUint16(nameOffset + 2);
      final storage = nameOffset + data.getUint16(nameOffset + 4);

      for (final wantedId in const [16, 1]) {
        for (var i = 0; i < count; i++) {
          final record = nameOffset + 6 + i * 12;
          if (record + 12 > bytes.length) break;
          if (data.getUint16(record + 6) != wantedId) continue;

          final platformId = data.getUint16(record);
          final length = data.getUint16(record + 8);
          final start = storage + data.getUint16(record + 10);
          if (start + length > bytes.length) continue;

          final name = _decode(platformId, bytes.sublist(start, start + length));
          if (name != null && name.isNotEmpty) return name;
        }
      }
    } catch (_) {
      // Fall through: caller uses the file name.
    }
    return null;
  }

  static String? _decode(int platformId, Uint8List raw) {
    if (platformId == 0 || platformId == 3) {
      // Unicode / Windows: UTF-16BE
      final units = <int>[
        for (var i = 0; i + 1 < raw.length; i += 2) (raw[i] << 8) | raw[i + 1],
      ];
      return String.fromCharCodes(units).trim();
    }
    if (platformId == 1) return ascii.decode(raw, allowInvalid: true).trim();
    return null;
  }
}
