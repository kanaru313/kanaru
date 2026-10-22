import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/text_keys.dart';
import 'package:kanaru/core/database/track_keys.dart';

void main() {
  test('search columns fold accents, case and đ like sortKey', () {
    final keys = trackKeysFor(
      title: 'Đừng Làm',
      artist: 'Sơn Tùng M-TP',
      album: 'Đen Vâu',
      albumArtist: 'Sơn Tùng M-TP',
      genre: 'Nhạc Trẻ',
    );
    expect(keys.artistSearch, 'son tung m-tp');
    expect(keys.albumSearch, 'den vau');
    expect(keys.albumArtistSearch, 'son tung m-tp');
    expect(keys.genreSearch, 'nhac tre');
  });

  test('search columns keep a leading "the"', () {
    final keys = trackKeysFor(title: 'Help', artist: 'The Beatles');
    expect(keys.artistSearch, 'the beatles');
    expect(keys.artistSort, 'beatles');
  });

  test('search columns are null with their tag', () {
    final keys = trackKeysFor(title: 'Untitled');
    expect(keys.artistSearch, isNull);
    expect(keys.albumSearch, isNull);
    expect(keys.albumArtistSearch, isNull);
    expect(keys.genreSearch, isNull);
  });

  // The index reads the title through `title_sort`. If its rule ever
  // changes, a separate title search column must be added.
  test('the title is searched through title_sort', () {
    for (final title in ['Đừng Làm', 'The Wall', 'Beyoncé']) {
      expect(trackKeysFor(title: title).titleSort, sortKey(title));
    }
  });
}
