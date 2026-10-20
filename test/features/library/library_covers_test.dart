import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' show AlbumKey;
import 'package:kanaru/features/library/albums/album_grid_tile.dart';
import 'package:kanaru/features/library/albums/album_list_tile.dart';
import 'package:kanaru/features/library/library_route_keys.dart';
import 'package:kanaru/features/library/songs/song_tile.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/indexer/fake_tag_reader.dart';
import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _covers = '/cache/kanaru/covers/512';
final _red = fakeCoverKey('red');
final _blue = fakeCoverKey('blue');

LibraryHarness _harness() => LibraryHarness(coverCacheDirectory: _covers);

/// The file paths of the cover images under [of].
List<String> _coverPaths(WidgetTester tester, Finder of) => [
  for (final image in tester.widgetList<Image>(
    find.descendant(of: of, matching: find.byType(Image)),
  ))
    ((image.image as ResizeImage).imageProvider as FileImage).file.path,
];

void main() {
  final tracks = [
    TestTrack('one', artist: 'Amy', album: 'Alpha', coverKey: _red),
    TestTrack('two', artist: 'Bob', album: 'Beta'),
  ];

  testWidgets('album grid and list show covers, else the placeholder', (
    tester,
  ) async {
    final h = _harness();
    await openWithTracks(tester, h, tracks, location: '/albums');

    Finder grid(String title) => find.ancestor(
      of: find.text(title),
      matching: find.byType(AlbumGridTile),
    );
    expect(_coverPaths(tester, grid('Alpha')), ['$_covers/$_red']);
    expect(_coverPaths(tester, grid('Beta')), isEmpty);
    expect(
      find.descendant(of: grid('Beta'), matching: find.byIcon(Icons.album)),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Grid'));
    await tester.pumpAndSettle();
    Finder row(String title) => find.ancestor(
      of: find.text(title),
      matching: find.byType(AlbumListTile),
    );
    expect(_coverPaths(tester, row('Alpha')), ['$_covers/$_red']);
    expect(_coverPaths(tester, row('Beta')), isEmpty);
    expect(
      find.descendant(of: row('Beta'), matching: find.byIcon(Icons.album)),
      findsOneWidget,
    );
  });

  testWidgets('the album page header shows the album cover', (tester) async {
    final h = _harness();
    await openWithTracks(tester, h, [
      TestTrack('a', artist: 'Amy', album: 'Alpha', track: 1),
      TestTrack('b', artist: 'Amy', album: 'Alpha', track: 2, coverKey: _red),
    ], location: albumLocation(const AlbumKey('amy', 'alpha')));

    expect(_coverPaths(tester, find.byType(CustomScrollView)), [
      '$_covers/$_red',
    ]);
  });

  testWidgets('songs show their cover, else the music note', (tester) async {
    final h = _harness();
    await openWithTracks(tester, h, tracks, location: '/songs');

    Finder song(String title) =>
        find.ancestor(of: find.text(title), matching: find.byType(SongTile));
    expect(_coverPaths(tester, song('one')), ['$_covers/$_red']);
    expect(_coverPaths(tester, song('two')), isEmpty);
    expect(
      find.descendant(
        of: song('two'),
        matching: find.byIcon(Icons.music_note_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an artist page uses the album cover, not its own tracks', (
    tester,
  ) async {
    final h = _harness();
    // The album's smallest key comes from the other artist's track.
    await openWithTracks(tester, h, [
      TestTrack(
        'mine',
        artist: 'Ann',
        album: 'Split',
        albumArtist: 'Ann',
        coverKey: _red,
      ),
      TestTrack(
        'theirs',
        artist: 'Zoe',
        album: 'Split',
        albumArtist: 'Ann',
        coverKey: _blue,
      ),
    ], location: artistLocation('ann'));

    final tile = find.byType(AlbumGridTile);
    expect(tile, findsOneWidget);
    expect(_blue.compareTo(_red), lessThan(0));
    expect(_coverPaths(tester, tile), ['$_covers/$_blue']);
    final song = find.ancestor(
      of: find.text('mine'),
      matching: find.byType(SongTile),
    );
    expect(_coverPaths(tester, song), ['$_covers/$_red']);
  });

  testWidgets('without a cover folder nothing loads an image', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, tracks, location: '/albums');

    expect(find.byType(Image), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AlbumGridTile),
        matching: find.byIcon(Icons.album),
      ),
      findsNWidgets(2),
    );
  });
}
