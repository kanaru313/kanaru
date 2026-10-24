import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/widgets/album_list_tile.dart';
import 'package:kanaru/shared/widgets/artist_tile.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';

import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import 'search_test_data.dart';

const _tracks = [
  TestTrack(
    'Old Song',
    artist: 'Sơn Tùng M-TP',
    album: 'Sky Tour',
    albumArtist: 'Sơn Tùng M-TP',
    year: 2010,
    path: '/m/1/old.flac',
  ),
  TestTrack(
    'New Song',
    artist: 'Sơn Tùng M-TP',
    album: 'Sky Tour',
    albumArtist: 'Sơn Tùng M-TP',
    year: 2018,
    path: '/m/1/new.mp3',
  ),
  TestTrack(
    'Other Song',
    artist: 'Adele',
    album: '25',
    albumArtist: 'Adele',
    year: 2018,
    path: '/m/1/other.mp3',
  ),
];

void main() {
  testWidgets('a field prefix from the URL narrows the songs only', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'artist:tung', tracks: _tracks);

    expect(find.byType(SongTile), findsNWidgets(2));
    expect(find.text('Other Song'), findsNothing);
    // The prefix is not free text, so the album and artist groups are off.
    expect(find.byType(AlbumListTile), findsNothing);
    expect(find.byType(ArtistTile), findsNothing);
  });

  testWidgets('a filter alone still lists songs, without other groups', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'year:2010', tracks: _tracks);

    expect(find.text('Old Song'), findsOneWidget);
    expect(find.byType(SongTile), findsOneWidget);
    expect(find.byType(AlbumListTile), findsNothing);
    expect(find.byType(ArtistTile), findsNothing);
  });

  testWidgets('quoted values and ranges combine', (tester) async {
    final h = LibraryHarness();
    await openSearch(
      tester,
      h,
      'artist:"son tung" year:>2015',
      tracks: _tracks,
    );

    expect(find.text('New Song'), findsOneWidget);
    expect(find.byType(SongTile), findsOneWidget);
  });

  testWidgets('free words mix with a format filter', (tester) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'song format:mp3', tracks: _tracks);

    expect(find.byType(SongTile), findsNWidgets(2));
    expect(find.text('Old Song'), findsNothing);
  });

  testWidgets('the unchanged query with no match uses the default message', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'year:1900', tracks: _tracks);

    expect(find.text('No results'), findsOneWidget);
    expect(
      find.textContaining('Nothing matches “year:1900”. Try fewer'),
      findsOneWidget,
    );
  });
}
