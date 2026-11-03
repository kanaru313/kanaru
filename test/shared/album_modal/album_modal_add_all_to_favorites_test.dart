import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' show AlbumKey;
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/database/playlist_writes.dart';
import 'package:kanaru/shared/widgets/library_grid/album_tile_data.dart';

import '../../features/library/browse_test_data.dart';
import '../../features/library/library_test_harness.dart';
import 'album_modal_test_support.dart';

// Stored out of page order, so the order of the page is told from the order
// the rows were stored in.
const _tracks = [
  TestTrack('a2', artist: 'Ann', album: 'Alpha', track: 2),
  TestTrack('a1', artist: 'Ann', album: 'Alpha', track: 1),
  TestTrack('b1', artist: 'Bob', album: 'Beta', track: 1),
];
const _alpha = AlbumTileData(
  key: AlbumKey('ann', 'alpha'),
  title: 'Alpha',
  artist: 'Ann',
);

void main() {
  /// Opens the Advanced page of the album, removes its tile, then taps the
  /// row. [seed] picks the page-order indexes already in Favorites.
  Future<(LibraryHarness, List<String>)> run(
    WidgetTester tester, {
    List<int>? seed,
    bool tileGone = true,
    bool breakReads = false,
  }) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/albums');
    final host = await pumpAlbumHost(
      tester,
      container: h.container,
      album: _alpha,
    );
    await tester.pumpAndSettle();
    final pagePaths = (await tester.runAsync(
      () async => [for (final t in await h.db.albumTracks(_alpha.key)) t.path],
    ))!;
    if (seed != null) {
      await tester.runAsync(() async {
        final id = await h.db.ensureFavoritesPlaylist(now: 1);
        await h.db.addMissingToPlaylist(id, [
          for (final i in seed) pagePaths[i],
        ]);
      });
    }
    await openAlbumModalOf(tester);
    await tapAlbumRow(tester, 'Advanced');
    if (breakReads) {
      // The album read then fails, as a locked or damaged library would.
      await tester.runAsync(() => h.db.customStatement('DROP TABLE tracks'));
    }
    if (tileGone) {
      host.shown.value = false;
      await tester.pump();
      expect(find.text('tile'), findsNothing);
    }
    await tester.tap(albumModalAction('add-all-to-favorites'));
    await settleIo(tester, h);
    await tester.pumpAndSettle();
    return (h, pagePaths);
  }

  Future<List<String>> favorites(WidgetTester tester, LibraryHarness h) async =>
      (await tester.runAsync(() async {
        final id = await h.db.favoritesPlaylistId();
        if (id == null) return <String>[];
        final rows =
            await (h.db.select(h.db.playlistEntries)
                  ..where((e) => e.playlistId.equals(id))
                  ..orderBy([(e) => OrderingTerm.asc(e.position)]))
                .get();
        return [for (final e in rows) e.path];
      }))!;

  testWidgets('it is the first row of the Advanced page', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/albums');
    await pumpAlbumHost(tester, container: h.container, album: _alpha);
    await tester.pumpAndSettle();
    await openAlbumModalOf(tester);
    await tapAlbumRow(tester, 'Advanced');

    expect(find.text('Add all to Favorites'), findsOneWidget);
    final add = tester.getTopLeft(albumModalAction('add-all-to-favorites'));
    for (final other in ['remove-from-library', 'delete-files']) {
      expect(
        add.dy,
        lessThan(tester.getTopLeft(albumModalAction(other)).dy),
        reason: other,
      );
    }
  });

  /// File names of [paths]: the tracks are stored as 0.flac (a2) and 1.flac
  /// (a1), so page order is track 1 then track 2.
  List<String> names(List<String> paths) => [
    for (final p in paths) p.substring(p.lastIndexOf('/') + 1),
  ];

  testWidgets('adds the local songs in page order and creates Favorites', (
    tester,
  ) async {
    final (h, _) = await run(tester);
    expect(names(await favorites(tester, h)), ['1.flac', '0.flac']);
    expect(find.text('Added to Favorites: Alpha'), findsOneWidget);
  });

  testWidgets('says how many were already there', (tester) async {
    final (h, pagePaths) = await run(tester, seed: [0]);
    expect(await favorites(tester, h), pagePaths);
    expect(
      find.text('Added 1 song to Favorites, 1 was already there'),
      findsOneWidget,
    );
  });

  testWidgets('says so when every song is already there', (tester) async {
    final (h, pagePaths) = await run(tester, seed: [0, 1]);
    expect(await favorites(tester, h), pagePaths);
    expect(find.text('Already in Favorites: Alpha'), findsOneWidget);
  });

  testWidgets('works with the tile still on screen', (tester) async {
    final (h, pagePaths) = await run(tester, tileGone: false);
    expect(await favorites(tester, h), pagePaths);
  });

  testWidgets('a failing read says so and leaves Favorites alone', (
    tester,
  ) async {
    final (h, pagePaths) = await run(tester, seed: [0], breakReads: true);
    expect(await favorites(tester, h), [pagePaths[0]]);
    expect(
      find.text("Couldn't save the playlist. See the log for details."),
      findsOneWidget,
    );
  });
}
