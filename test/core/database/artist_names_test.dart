import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/artist_names.dart';

void main() {
  test('splits on every agreed separator', () {
    const table = {
      'A;B': ['A', 'B'],
      'A ; B': ['A', 'B'],
      'A; B': ['A', 'B'],
      'A feat. B': ['A', 'B'],
      'A Feat B': ['A', 'B'],
      'A FT. B': ['A', 'B'],
      'A ft B': ['A', 'B'],
      'A featuring B': ['A', 'B'],
      'A with B': ['A', 'B'],
      'A (feat. B)': ['A', 'B'],
      'A [ft. B; C]': ['A', 'B', 'C'],
      'A (with B) ; C': ['A', 'B', 'C'],
      'A/B': ['A', 'B'],
      'A / B': ['A', 'B'],
      'Ban nhạc Hương Mùa Hè;SUNI Hạ Linh': [
        'Ban nhạc Hương Mùa Hè',
        'SUNI Hạ Linh',
      ],
    };
    for (final MapEntry(:key, :value) in table.entries) {
      expect(splitArtists(key), value, reason: key);
    }
  });

  test('keeps names with a slash exception, commas and ampersands', () {
    expect(splitArtists('AC/DC'), ['AC/DC']);
    expect(splitArtists('ac/dc feat. X'), ['ac/dc', 'X']);
    expect(splitArtists('X/AC/DC'), ['X', 'AC/DC']);
    expect(splitArtists('A, B'), ['A, B']);
    expect(splitArtists('Simon & Garfunkel'), ['Simon & Garfunkel']);
  });

  test('featuring words split only as whole words between spaces', () {
    expect(splitArtists('Weather Report'), ['Weather Report']);
    expect(splitArtists('Withers'), ['Withers']);
    expect(splitArtists('Lefty Feather'), ['Lefty Feather']);
    expect(splitArtists('Daft Punk'), ['Daft Punk']);
  });

  test('trims, drops empty parts and repeats, keeps the order', () {
    expect(splitArtists('A; A'), ['A']);
    expect(splitArtists('B; a; A'), ['B', 'a']);
    expect(splitArtists(' ; A ;; '), ['A']);
    expect(splitArtists(null), isEmpty);
    expect(splitArtists(''), isEmpty);
  });

  test('keys are Unicode lower case, cut to 256 characters', () {
    expect(artistKey('Đen'), artistKey('đen'));
    expect(artistKey('ÁNH'), 'ánh');
    expect(artistKey('😀' * 300).runes.length, maxKeyLength);
    expect(artistKeys('Đen feat. SUNI Hạ Linh'), ['đen', 'suni hạ linh']);
  });

  test('slash exceptions match whole names only', () {
    expect(splitArtists('Shellac/DC Talk'), ['Shellac', 'DC Talk']);
    expect(splitArtists('DC Talk/AC/DC'), ['DC Talk', 'AC/DC']);
    expect(splitArtists('X / AC/DC / Y'), ['X', 'AC/DC', 'Y']);
    expect(splitArtists('AC/DCX'), ['AC', 'DCX']);
  });

  test('any whitespace around featuring words splits the same way', () {
    for (final tag in ['A\tfeat. B', 'A\u00a0feat.\u00a0B', 'A  ft  B']) {
      expect(splitArtists(tag), ['A', 'B'], reason: tag);
    }
  });

  test('control characters become spaces and never reach keys', () {
    // Looks like an internal placeholder; must not crash.
    expect(splitArtists('A\u00000\u0000B'), ['A 0 B']);
    expect(splitArtists('A\u001e;B\u001f'), ['A', 'B']);
    for (final tag in ['A\u001eB', 'X\u001f; Y\u0000', '\u0000']) {
      for (final key in artistKeys(tag)) {
        expect(key.codeUnits.every((u) => u >= 0x20), isTrue, reason: tag);
      }
    }
    expect(textKey('Ti\u001ftle'), 'ti tle');
  });
}
