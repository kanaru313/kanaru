import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/library_sort.dart';
import 'package:kanaru/features/library/albums/album_sort.dart';
import 'package:kanaru/shared/sort_compare.dart';

import '../features/library/album_sort_test.dart' show album;

void main() {
  // U+1F600 is the surrogate pair D83D DE00: UTF-16 puts it before U+FF71,
  // SQLite (and code points) after.
  const emoji = '\u{1F600}', kana = 'ｱ';

  group('compareCodePoints', () {
    test('orders supplementary characters after the BMP, like SQLite', () {
      expect(emoji.compareTo(kana), lessThan(0), reason: 'UTF-16 order');
      expect(compareCodePoints(emoji, kana), greaterThan(0));
      expect(compareCodePoints(kana, emoji), lessThan(0));
      expect(compareCodePoints('a$emoji', 'a'), greaterThan(0));
    });

    test('matches compareTo where no surrogate is involved', () {
      for (final (a, b) in [
        ('', ''),
        ('', 'a'),
        ('abc', 'abd'),
        ('abc', 'ab'),
        ('same', 'same'),
        ('ｱ', 'z'),
      ]) {
        expect(compareCodePoints(a, b).sign, a.compareTo(b).sign, reason: a);
      }
    });

    test('orders by the first difference and by prefix', () {
      expect(compareCodePoints(emoji, emoji), 0);
      expect(compareCodePoints(emoji, '$emoji!'), lessThan(0));
      expect(compareCodePoints('\u{1F601}', emoji), greaterThan(0));
    });
  });

  test('albums sort by code point, like the Songs list', () {
    final sorted = sortAlbums([
      album(emoji),
      album(kana),
    ], const SortChoice(AlbumSortField.title));
    expect([for (final a in sorted) a.title], [kana, emoji]);
  });
}
