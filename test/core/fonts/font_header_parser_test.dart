import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/font_header_parser.dart';

import 'font_test_helpers.dart';

void main() {
  Uint8List header(List<int> magic) => Uint8List.fromList([...magic, ...List.filled(8, 0)]);

  test('accepts TrueType, OpenType-CFF and Apple true', () {
    expect(FontHeaderParser.isValidFontBytes(header([0x00, 0x01, 0x00, 0x00])), isTrue);
    expect(FontHeaderParser.isValidFontBytes(header([0x4F, 0x54, 0x54, 0x4F])), isTrue);
    expect(FontHeaderParser.isValidFontBytes(header([0x74, 0x72, 0x75, 0x65])), isTrue);
  });

  test('rejects collections, zips and short input', () {
    expect(FontHeaderParser.isValidFontBytes(header([0x74, 0x74, 0x63, 0x66])), isFalse); // ttcf
    expect(FontHeaderParser.isValidFontBytes(header([0x50, 0x4B, 0x03, 0x04])), isFalse); // zip
    expect(FontHeaderParser.isValidFontBytes(Uint8List(4)), isFalse);
  });

  test('reads the family name from the name table', () {
    expect(FontHeaderParser.extractFontName(buildFont('Lora')), 'Lora');
    expect(FontHeaderParser.extractFontName(buildFont('Phông Chữ')), 'Phông Chữ');
    expect(FontHeaderParser.extractFontName(buildFont('Typo Family', nameId: 16)), 'Typo Family');
  });

  test('returns null for unrelated name ids and garbage', () {
    expect(FontHeaderParser.extractFontName(buildFont('Full Name', nameId: 4)), isNull);
    expect(FontHeaderParser.extractFontName(Uint8List.fromList(List.filled(40, 7))), isNull);
  });
}
