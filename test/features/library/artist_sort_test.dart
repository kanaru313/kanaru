import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/library_sort.dart';
import 'package:kanaru/features/library/artists/artist_sort.dart';
import 'package:kanaru/features/library/artists/artist_summaries.dart';

ArtistSummary artist(String name, int songs, int albums) => ArtistSummary(
  key: name.toLowerCase(),
  name: name,
  songCount: songs,
  albumCount: albums,
);

void main() {
  final artists = [
    artist('bob', 5, 1),
    artist('Ann', 2, 3),
    artist('cy', 2, 0),
  ];

  List<String> order(ArtistSortField field, {bool descending = false}) => [
    for (final a in sortArtists(
      artists,
      SortChoice(field, descending: descending),
    ))
      a.name,
  ];

  test('by name ignoring case', () {
    expect(order(ArtistSortField.name), ['Ann', 'bob', 'cy']);
    expect(order(ArtistSortField.name, descending: true), ['cy', 'bob', 'Ann']);
  });

  test('by counts; ties by name ascending', () {
    expect(order(ArtistSortField.songCount), ['Ann', 'cy', 'bob']);
    expect(order(ArtistSortField.songCount, descending: true), [
      'bob',
      'Ann',
      'cy',
    ]);
    expect(order(ArtistSortField.albumCount), ['cy', 'bob', 'Ann']);
  });
}
