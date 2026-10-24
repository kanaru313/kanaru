import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/settings/library_sort.dart';
import 'package:kanaru/features/library/albums/album_sort.dart';

AlbumSummary album(
  String title, {
  String? artist,
  int? year,
  int addedAt = 0,
  String key = '',
  bool various = false,
}) => AlbumSummary(
  key: AlbumKey(key, title.toLowerCase()),
  title: title,
  artist: artist,
  year: year,
  trackCount: 1,
  addedAt: addedAt,
  variousArtists: various,
);

void main() {
  final albums = [
    album('b', artist: 'Zed', year: 2001, addedAt: 3),
    album('A', year: 1990, addedAt: 1),
    album('c', artist: 'amy', addedAt: 2),
    album('a', artist: 'Bob', year: 1990, addedAt: 4, key: 'bob'),
  ];

  List<String> order(AlbumSortField field, {bool descending = false}) => [
    for (final a in sortAlbums(
      albums,
      SortChoice(field, descending: descending),
    ))
      '${a.title}${a.key.artistKey}',
  ];

  test('title ignores case; ties fall back to the key', () {
    expect(order(AlbumSortField.title), ['A', 'abob', 'b', 'c']);
    expect(order(AlbumSortField.title, descending: true), [
      'c',
      'b',
      'A',
      'abob',
    ]);
  });

  test('unknown artist and year go last both ways', () {
    expect(order(AlbumSortField.artist), ['c', 'abob', 'b', 'A']);
    expect(order(AlbumSortField.artist, descending: true), [
      'b',
      'abob',
      'c',
      'A',
    ]);
    expect(order(AlbumSortField.year), ['A', 'abob', 'b', 'c']);
    expect(order(AlbumSortField.year, descending: true), [
      'b',
      'A',
      'abob',
      'c',
    ]);
  });

  test('date added', () {
    expect(order(AlbumSortField.dateAdded), ['A', 'c', 'b', 'abob']);
    expect(order(AlbumSortField.dateAdded, descending: true), [
      'abob',
      'b',
      'c',
      'A',
    ]);
  });

  test('does not change the input list', () {
    final input = [...albums];
    sortAlbums(input, const SortChoice(AlbumSortField.year));
    expect(input, albums);
  });

  test('a merged album sorts by artist with the unknown ones, last', () {
    final input = [
      album('v', artist: 'Aaa', various: true),
      album('n', artist: 'Mid'),
      album('u'),
    ];
    for (final descending in [false, true]) {
      final sorted = sortAlbums(
        input,
        SortChoice(AlbumSortField.artist, descending: descending),
      );
      expect(sorted.first.title, 'n');
      expect(sorted.skip(1).map((a) => a.title), ['u', 'v']);
    }
  });
}
