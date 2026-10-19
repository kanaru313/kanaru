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
}
