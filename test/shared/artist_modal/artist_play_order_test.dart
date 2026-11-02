import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/play_history_writes.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/home/home_screen.dart';
import 'package:kanaru/shared/artist_summaries.dart';
import 'package:kanaru/shared/widgets/artist_tile.dart';
import 'package:kanaru/shared/widgets/library_grid/artist_grid_tile.dart';

import '../../features/home/home_test_harness.dart';
import '../../features/library/browse_test_data.dart';
import '../../features/library/library_test_harness.dart';
import 'artist_modal_test_support.dart';

// The page of Ann lists her own albums by year (Alpha, Zulu), then the album
// she appears on (Mid). The database orders them by album artist and album
// key instead: Mid, Zulu, Alpha.
const _tracks = [
  TestTrack(
    'Zulu',
    artist: 'Ann',
    album: 'Early',
    albumArtist: 'Ann',
    year: 2005,
  ),
  TestTrack(
    'Alpha',
    artist: 'Ann',
    album: 'Late',
    albumArtist: 'Ann',
    year: 2000,
  ),
  TestTrack('Mid', artist: 'X; Ann', album: 'Theirs', albumArtist: 'Aaron'),
];
const _pageOrder = ['Alpha', 'Zulu', 'Mid'];
const _ann = ArtistSummary(
  key: 'ann',
  name: 'Ann',
  songCount: 3,
  albumCount: 2,
);

List<String> _queue(LibraryHarness h) => [
  for (final t in h.container.read(playerServiceProvider).queue.tracks) t.title,
];

void main() {
  testWidgets('the Home card queues the songs in page order', (tester) async {
    final h = HomeHarness();
    for (final t in _tracks) {
      await h.addTrack(
        '/${t.title}',
        artist: t.artist,
        album: t.album,
        albumArtist: t.albumArtist,
        year: t.year,
      );
    }
    await h.db.insertLibraryPlay(
      path: '/Alpha',
      playedAt: h.now.millisecondsSinceEpoch - 1000,
      listenedMs: 200000,
    );
    await h.pump(tester, const HomeScreen(), height: 2400);

    await tester.tap(
      find.descendant(
        of: find.descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(ArtistGridTile),
        ),
        matching: find.text('Ann'),
      ),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to queue'));
    // The songs are read from the database after the tap.
    await tester.runAsync(() => h.db.customSelect('SELECT 1').get());
    await tester.pumpAndSettle();

    final queue = h.container.read(playerServiceProvider).queue.tracks;
    expect(
      [for (final t in queue) t.title],
      [for (final t in _pageOrder) 'T /$t'],
    );
  });

  testWidgets('the Search Play button plays the songs in page order', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/search?q=ann');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    final tile = find.byType(ArtistTile).first;
    await mouse.addPointer(location: tester.getCenter(tile));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: tile, matching: find.byTooltip('Play artist')),
    );
    await settleIo(tester, h);

    expect(_queue(h), _pageOrder);
  });

  // Guards the order shared with the page; the modal already used it.
  testWidgets('the artist modal Play all plays the songs in page order', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/artists');
    await pumpArtistHost(
      tester,
      container: h.container,
      artist: _ann,
      enqueueForReal: true,
    );
    await tester.pumpAndSettle();
    await openArtistModalOf(tester);

    await tester.tap(find.text('Play all'));
    await settleIo(tester, h);
    await tester.pumpAndSettle();

    expect(_queue(h), _pageOrder);
  });
}
