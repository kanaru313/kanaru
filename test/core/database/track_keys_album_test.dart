import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/track_keys.dart';

void main() {
  test('album artist key: album artists, else the first track artist', () {
    expect(albumArtistKey(null, 'X feat. Y'), 'x');
    expect(albumArtistKey('A; B', 'X'), 'a; b');
    expect(albumArtistKey(null, null), '');
    expect(albumArtistKey('Various Artists', 'Q'), 'various artists');
  });

  test('each artist key is cut, the joined string is not', () {
    final long = 'n' * 300;
    final joined = albumArtistKey('$long; Other', null);
    expect(joined.split('; '), ['n' * 256, 'other']);
  });

  test('album title key keeps accents and folds case', () {
    expect(albumTitleKey('Ánh Best'), 'ánh best');
    expect(albumTitleKey('Anh Best'), 'anh best');
  });
}
