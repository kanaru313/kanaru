import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lyrics_text_decoder.dart';

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

Uint8List _utf16(String text, {required bool little}) {
  final out = <int>[];
  for (final unit in text.codeUnits) {
    final pair = [unit & 0xFF, unit >> 8];
    out.addAll(little ? pair : pair.reversed);
  }
  return _bytes(out);
}

void main() {
  const text = 'Lời bài hát 🎵\n[00:01.00]歌';

  test('UTF-8 with and without BOM', () {
    expect(decodeLyricsBytes(_bytes(utf8.encode(text))), text);
    expect(
      decodeLyricsBytes(_bytes([0xEF, 0xBB, 0xBF, ...utf8.encode(text)])),
      text,
    );
  });

  test('UTF-16 LE and BE with BOM', () {
    expect(
      decodeLyricsBytes(_bytes([0xFF, 0xFE, ..._utf16(text, little: true)])),
      text,
    );
    expect(
      decodeLyricsBytes(_bytes([0xFE, 0xFF, ..._utf16(text, little: false)])),
      text,
    );
  });

  test('UTF-16 with an odd trailing byte or a lone surrogate', () {
    expect(decodeLyricsBytes(_bytes([0xFF, 0xFE, 0x41, 0x00, 0x42])), 'A');
    expect(
      decodeLyricsBytes(_bytes([0xFF, 0xFE, 0x00, 0xD8, 0x41, 0x00])),
      '�A',
    );
  });

  test('bytes that are not UTF-8 are read as Latin-1', () {
    expect(decodeLyricsBytes(_bytes([0x43, 0x61, 0x66, 0xE9])), 'Café');
  });

  test('empty input', () {
    expect(decodeLyricsBytes(Uint8List(0)), '');
  });
}
