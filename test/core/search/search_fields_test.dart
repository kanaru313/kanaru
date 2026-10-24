import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/search/search_fields.dart';

void main() {
  test('all preset has the five tag fields and no file text', () {
    expect(SearchFieldPreset.all.fields, {
      SearchField.title,
      SearchField.artist,
      SearchField.album,
      SearchField.albumArtist,
      SearchField.genre,
    });
    expect(usesFileText(SearchFieldPreset.all.fields), isFalse);
    expect(defaultSearchFields, SearchFieldPreset.all.fields);
  });

  test('title only preset is the title field', () {
    expect(SearchFieldPreset.titleOnly.fields, {SearchField.title});
  });

  test('ftsColumns follows table column order, not set order', () {
    expect(
      ftsColumns({SearchField.genre, SearchField.title, SearchField.album}),
      ['title_sort', 'album_search', 'genre_search'],
    );
    expect(ftsColumns(SearchFieldPreset.all.fields), [
      'title_sort',
      'artist_search',
      'album_search',
      'album_artist_search',
      'genre_search',
    ]);
  });

  test('file name and comment have no column', () {
    expect(ftsColumns({SearchField.fileName, SearchField.comment}), isEmpty);
  });

  test('usesFileText is true for file name or comment', () {
    expect(usesFileText({SearchField.title, SearchField.fileName}), isTrue);
    expect(usesFileText({SearchField.comment}), isTrue);
    expect(usesFileText({SearchField.title}), isFalse);
  });
}
