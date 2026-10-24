import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/artists/artist_grid_tile.dart';
import 'package:kanaru/features/library/folders/folder_grid_tile.dart';
import 'package:kanaru/features/library/genres/genre_grid_tile.dart';
import 'package:kanaru/features/library/songs/song_grid_tile.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

void main() {
  const tracks = [
    TestTrack(
      'a',
      artist: 'Ann',
      album: 'Al',
      genre: 'Rock',
      path: '/m/R/a.flac',
    ),
    TestTrack(
      'b',
      artist: 'Bob',
      album: 'Bl',
      genre: 'Pop',
      path: '/m/R/b.flac',
    ),
  ];

  Future<void> open(WidgetTester tester, String location) =>
      openWithTracks(tester, LibraryHarness(), tracks, location: location);

  testWidgets('Songs opens as a grid', (tester) async {
    await open(tester, '/songs');
    expect(find.byType(SongGridTile), findsNWidgets(2));
    expect(find.byType(SongTile), findsNothing);
  });

  testWidgets('Artists opens as a grid', (tester) async {
    await open(tester, '/artists');
    expect(find.byType(ArtistGridTile), findsNWidgets(2));
  });

  testWidgets('Genres opens as a grid', (tester) async {
    await open(tester, '/genres');
    expect(find.byType(GenreGridTile), findsNWidgets(2));
  });

  testWidgets('Folders opens as a grid', (tester) async {
    await open(tester, '/folders');
    expect(find.byType(FolderGridTile), findsWidgets);
  });
}
