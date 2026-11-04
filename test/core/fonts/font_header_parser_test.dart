import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/font_header_parser.dart';

import 'font_test_helpers.dart';

List<int> _utf16Be(String text) {
  final result = <int>[];
  for (var i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    result.add((code >> 8) & 0xFF);
    result.add(code & 0xFF);
  }
  return result;
}

void main() {
  Uint8List header(List<int> magic) =>
      Uint8List.fromList([...magic, ...List.filled(8, 0)]);

  group('FontHeaderParser.isValidFontBytes', () {
    test('accepts TrueType, OpenType-CFF and Apple true', () {
      expect(FontHeaderParser.isValidFontBytes(header([0x00, 0x01, 0x00, 0x00])), isTrue);
      expect(FontHeaderParser.isValidFontBytes(header([0x4F, 0x54, 0x54, 0x4F])), isTrue);
      expect(FontHeaderParser.isValidFontBytes(header([0x74, 0x72, 0x75, 0x65])), isTrue);
    });

    test('rejects collections, zips and short input', () {
      expect(FontHeaderParser.isValidFontBytes(header([0x74, 0x74, 0x63, 0x66])), isFalse); // ttcf
      expect(FontHeaderParser.isValidFontBytes(header([0x50, 0x4B, 0x03, 0x04])), isFalse); // zip
      expect(FontHeaderParser.isValidFontBytes(Uint8List(11)), isFalse);
      expect(FontHeaderParser.isValidFontBytes(Uint8List(0)), isFalse);
    });
  });

  group('FontHeaderParser.extractFontName', () {
    test('reads the family name from Windows UTF-16BE (Platform 3)', () {
      final font = buildMultiRecordFont(names: [
        (nameId: 1, platformId: 3, bytes: _utf16Be('Windows Family')),
      ]);
      expect(FontHeaderParser.extractFontName(font), 'Windows Family');
    });

    test('reads the family name from Unicode UTF-16BE (Platform 0)', () {
      final font = buildMultiRecordFont(names: [
        (nameId: 1, platformId: 0, bytes: _utf16Be('Unicode Family')),
      ]);
      expect(FontHeaderParser.extractFontName(font), 'Unicode Family');
    });

    test('reads the family name from Macintosh ASCII (Platform 1)', () {
      final font = buildMultiRecordFont(names: [
        (nameId: 1, platformId: 1, bytes: ascii.encode('Mac Roman Family')),
      ]);
      expect(FontHeaderParser.extractFontName(font), 'Mac Roman Family');
    });

    test('prioritizes Platform 3 Windows over Platform 1 Macintosh when both exist', () {
      // In OpenType tables, Platform 1 comes before Platform 3.
      // This test ensures Platform 3 UTF-16BE is selected instead of truncated Platform 1 ASCII.
      final font = buildMultiRecordFont(names: [
        (nameId: 1, platformId: 1, bytes: ascii.encode('Phong Chu')),
        (nameId: 1, platformId: 3, bytes: _utf16Be('Phông Chữ Tiếng Việt')),
      ]);
      expect(FontHeaderParser.extractFontName(font), 'Phông Chữ Tiếng Việt');
    });

    test('prefers Name ID 16 (Typographic Family) over Name ID 1 (Font Family)', () {
      final font = buildMultiRecordFont(names: [
        (nameId: 1, platformId: 3, bytes: _utf16Be('Regular Family')),
        (nameId: 16, platformId: 3, bytes: _utf16Be('Typographic Family Pro')),
      ]);
      expect(FontHeaderParser.extractFontName(font), 'Typographic Family Pro');
    });

    test('handles Vietnamese and CJK UTF-16BE characters properly', () {
      expect(FontHeaderParser.extractFontName(buildFont('Phông Chữ Tiếng Việt')), 'Phông Chữ Tiếng Việt');
      expect(FontHeaderParser.extractFontName(buildFont('思源黑体')), '思源黑体');
    });

    test('returns null for unrelated name ids and garbage', () {
      expect(FontHeaderParser.extractFontName(buildFont('Full Name', nameId: 4)), isNull);
      expect(FontHeaderParser.extractFontName(Uint8List.fromList(List.filled(40, 7))), isNull);
      expect(FontHeaderParser.extractFontName(Uint8List(8)), isNull);
    });

    test('gracefully returns null on corrupted table offset pointing past EOF', () {
      final font = buildMultiRecordFont(names: [
        (nameId: 1, platformId: 3, bytes: _utf16Be('Test')),
      ]);
      final corrupted = Uint8List.fromList(font);
      corrupted[20] = 0xFF; // table offset in table record (bytes 20..23)
      corrupted[21] = 0xFF;
      expect(FontHeaderParser.extractFontName(corrupted), isNull);
    });

    test('extracts real font names from bundled asset fonts', () {
      final nunitoFile = File('assets/fonts/Nunito-Regular.ttf');
      if (nunitoFile.existsSync()) {
        final nunitoBytes = nunitoFile.readAsBytesSync();
        expect(FontHeaderParser.isValidFontBytes(nunitoBytes), isTrue);
        expect(FontHeaderParser.extractFontName(nunitoBytes), 'Nunito');
      }

      final interFile = File('assets/fonts/Inter-Regular.ttf');
      if (interFile.existsSync()) {
        final interBytes = interFile.readAsBytesSync();
        expect(FontHeaderParser.isValidFontBytes(interBytes), isTrue);
        expect(FontHeaderParser.extractFontName(interBytes), 'Inter');
      }
    });
  });
}
