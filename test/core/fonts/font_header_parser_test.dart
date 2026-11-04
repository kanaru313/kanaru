import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/font_header_parser.dart';

Uint8List _encodeUtf16Be(String text) {
  final result = Uint8List(text.length * 2);
  for (var i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    result[i * 2] = (code >> 8) & 0xFF;
    result[i * 2 + 1] = code & 0xFF;
  }
  return result;
}

Uint8List _buildMinimalFont({
  List<int> magic = const [0x00, 0x01, 0x00, 0x00],
  List<({int nameId, int platformId, Uint8List bytes})> names = const [],
}) {
  final tableDirLength = 12 + (names.isEmpty ? 0 : 16);
  var storageLength = 0;
  for (final n in names) {
    storageLength += n.bytes.length;
  }
  final nameRecordsLength = names.length * 12;
  final nameTableLength = names.isEmpty ? 0 : 6 + nameRecordsLength + storageLength;
  final totalLength = tableDirLength + nameTableLength;

  final data = ByteData(totalLength);
  for (var i = 0; i < 4; i++) {
    data.setUint8(i, magic[i]);
  }
  final numTables = names.isEmpty ? 0 : 1;
  data.setUint16(4, numTables);
  data.setUint16(6, 0); // searchRange
  data.setUint16(8, 0); // entrySelector
  data.setUint16(10, 0); // rangeShift

  if (names.isNotEmpty) {
    // Table record for 'name'
    data.setUint8(12, 0x6E); // n
    data.setUint8(13, 0x61); // a
    data.setUint8(14, 0x6D); // m
    data.setUint8(15, 0x65); // e
    data.setUint32(16, 0); // checksum
    data.setUint32(20, tableDirLength); // offset
    data.setUint32(24, nameTableLength); // length

    // Name table header
    data.setUint16(tableDirLength, 0); // format
    data.setUint16(tableDirLength + 2, names.length); // count
    data.setUint16(tableDirLength + 4, 6 + nameRecordsLength); // stringOffset

    var stringStorageOffset = 0;
    final storageStart = tableDirLength + 6 + nameRecordsLength;

    for (var i = 0; i < names.length; i++) {
      final recordOffset = tableDirLength + 6 + i * 12;
      final entry = names[i];
      data.setUint16(recordOffset, entry.platformId);
      data.setUint16(recordOffset + 2, 1); // encodingId
      data.setUint16(recordOffset + 4, 0x0409); // languageId (en-US)
      data.setUint16(recordOffset + 6, entry.nameId);
      data.setUint16(recordOffset + 8, entry.bytes.length);
      data.setUint16(recordOffset + 10, stringStorageOffset);

      for (var b = 0; b < entry.bytes.length; b++) {
        data.setUint8(storageStart + stringStorageOffset + b, entry.bytes[b]);
      }
      stringStorageOffset += entry.bytes.length;
    }
  }

  return data.buffer.asUint8List();
}

void main() {
  group('FontHeaderParser.isValidFontBytes', () {
    test('rejects bytes shorter than 12', () {
      expect(FontHeaderParser.isValidFontBytes(Uint8List(11)), isFalse);
      expect(FontHeaderParser.isValidFontBytes(Uint8List(0)), isFalse);
    });

    test('accepts TrueType 0x00010000', () {
      final bytes = Uint8List(12);
      bytes[0] = 0x00;
      bytes[1] = 0x01;
      bytes[2] = 0x00;
      bytes[3] = 0x00;
      expect(FontHeaderParser.isValidFontBytes(bytes), isTrue);
    });

    test('accepts OpenType-CFF OTTO', () {
      final bytes = Uint8List(12);
      bytes[0] = 0x4F; // O
      bytes[1] = 0x54; // T
      bytes[2] = 0x54; // T
      bytes[3] = 0x4F; // O
      expect(FontHeaderParser.isValidFontBytes(bytes), isTrue);
    });

    test('accepts Apple true font', () {
      final bytes = Uint8List(12);
      bytes[0] = 0x74; // t
      bytes[1] = 0x72; // r
      bytes[2] = 0x75; // u
      bytes[3] = 0x65; // e
      expect(FontHeaderParser.isValidFontBytes(bytes), isTrue);
    });

    test('rejects TrueType Collection ttcf', () {
      final bytes = Uint8List(12);
      bytes[0] = 0x74; // t
      bytes[1] = 0x74; // t
      bytes[2] = 0x63; // c
      bytes[3] = 0x66; // f
      expect(FontHeaderParser.isValidFontBytes(bytes), isFalse);
    });

    test('rejects unknown magic bytes', () {
      final bytes = Uint8List.fromList([
        0x50, 0x4B, 0x03, 0x04, // ZIP header
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
      ]);
      expect(FontHeaderParser.isValidFontBytes(bytes), isFalse);
    });
  });

  group('FontHeaderParser.extractFontName', () {
    test('returns null for invalid font header or too short bytes', () {
      expect(FontHeaderParser.extractFontName(Uint8List(8)), isNull);
      expect(FontHeaderParser.extractFontName(Uint8List(20)), isNull);
    });

    test('returns null when name table is not present', () {
      final bytes = _buildMinimalFont(names: []);
      expect(FontHeaderParser.extractFontName(bytes), isNull);
    });

    test('extracts font family (Name ID 1) with Windows UTF-16BE (Platform 3)', () {
      final nameBytes = _encodeUtf16Be('My Custom Family');
      final font = _buildMinimalFont(
        names: [
          (nameId: 1, platformId: 3, bytes: nameBytes),
        ],
      );
      expect(FontHeaderParser.extractFontName(font), 'My Custom Family');
    });

    test('extracts font family with Unicode UTF-16BE (Platform 0)', () {
      final nameBytes = _encodeUtf16Be('Unicode Font');
      final font = _buildMinimalFont(
        names: [
          (nameId: 1, platformId: 0, bytes: nameBytes),
        ],
      );
      expect(FontHeaderParser.extractFontName(font), 'Unicode Font');
    });

    test('extracts font family with Macintosh ASCII (Platform 1)', () {
      final nameBytes = Uint8List.fromList(ascii.encode('Mac Roman Family'));
      final font = _buildMinimalFont(
        names: [
          (nameId: 1, platformId: 1, bytes: nameBytes),
        ],
      );
      expect(FontHeaderParser.extractFontName(font), 'Mac Roman Family');
    });

    test('prefers Name ID 16 (Typographic Family) over Name ID 1 (Font Family)', () {
      final familyBytes = _encodeUtf16Be('Regular Family');
      final typoBytes = _encodeUtf16Be('Typographic Family Pro');

      final font = _buildMinimalFont(
        names: [
          (nameId: 1, platformId: 3, bytes: familyBytes),
          (nameId: 16, platformId: 3, bytes: typoBytes),
        ],
      );
      expect(FontHeaderParser.extractFontName(font), 'Typographic Family Pro');
    });

    test('handles Vietnamese and CJK UTF-16BE characters properly', () {
      final vnBytes = _encodeUtf16Be('Phông Chữ Tiếng Việt');
      final fontVn = _buildMinimalFont(
        names: [
          (nameId: 1, platformId: 3, bytes: vnBytes),
        ],
      );
      expect(FontHeaderParser.extractFontName(fontVn), 'Phông Chữ Tiếng Việt');

      final cjkBytes = _encodeUtf16Be('思源黑体');
      final fontCjk = _buildMinimalFont(
        names: [
          (nameId: 1, platformId: 3, bytes: cjkBytes),
        ],
      );
      expect(FontHeaderParser.extractFontName(fontCjk), '思源黑体');
    });

    test('gracefully returns null on corrupted table offset', () {
      final font = _buildMinimalFont(
        names: [
          (nameId: 1, platformId: 3, bytes: _encodeUtf16Be('Test')),
        ],
      );
      // Corrupt the table offset to point past end of file
      final corrupted = Uint8List.fromList(font);
      corrupted[20] = 0xFF;
      corrupted[21] = 0xFF;
      expect(FontHeaderParser.extractFontName(corrupted), isNull);
    });

    test('extracts real font names from bundled asset fonts', () {
      final nunitoBytes = File('assets/fonts/Nunito-Regular.ttf').readAsBytesSync();
      expect(FontHeaderParser.isValidFontBytes(nunitoBytes), isTrue);
      expect(FontHeaderParser.extractFontName(nunitoBytes), 'Nunito');

      final interBytes = File('assets/fonts/Inter-Regular.ttf').readAsBytesSync();
      expect(FontHeaderParser.isValidFontBytes(interBytes), isTrue);
      expect(FontHeaderParser.extractFontName(interBytes), 'Inter');
    });
  });
}
