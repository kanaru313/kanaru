import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/shared/artist_summaries.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/library/browse_test_data.dart';
import '../../features/library/library_test_harness.dart';
import 'artist_modal_test_support.dart';

// Stored out of page order, so the order of the page is told from the order
// the rows were stored in: the page lists Gamma (1990) before Alpha (2000).
const _tracks = [
  TestTrack('a2', artist: 'Ann', album: 'Alpha', track: 2, year: 2000),
  TestTrack('a1', artist: 'Ann', album: 'Alpha', track: 1, year: 2000),
  TestTrack('g1', artist: 'Ann', album: 'Gamma', track: 1, year: 1990),
  TestTrack('b1', artist: 'Bob', album: 'Beta', track: 1),
];
const _ann = ArtistSummary(
  key: 'ann',
  name: 'Ann',
  songCount: 3,
  albumCount: 2,
);

void main() {
  List<String> queue(LibraryHarness h) => [
    for (final t in h.container.read(playerServiceProvider).queue.tracks)
      t.title,
  ];

  /// Opens the modal of the artist, optionally goes to Advanced, removes the
  /// row, then taps [label] (or the row with action [id]).
  Future<(LibraryHarness, ArtistHost)> run(
    WidgetTester tester,
    String label, {
    bool advanced = false,
  }) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/artists');
    final host = await pumpArtistHost(
      tester,
      container: h.container,
      artist: _ann,
      enqueueForReal: true,
    );
    await tester.pumpAndSettle();
    await openArtistModalOf(tester);
    if (advanced) {
      // The two albums make the first page taller than the dialog.
      await tester.ensureVisible(find.text('Advanced'));
      await tester.pumpAndSettle();
      await tapArtistRow(tester, 'Advanced');
    }
    host.shown.value = false;
    await tester.pump();
    expect(find.text('tile'), findsNothing);

    await tester.tap(find.text(label));
    await settleIo(tester, h);
    await tester.pumpAndSettle();
    return (h, host);
  }

  testWidgets('Play next queues the songs in page order', (tester) async {
    final (h, _) = await run(tester, 'Play next');
    expect(queue(h), ['g1', 'a1', 'a2']);
    expect(find.text('Playing: Ann'), findsOneWidget);
  });

  testWidgets('Add to queue queues the songs in page order', (tester) async {
    final (h, _) = await run(tester, 'Add to queue');
    expect(queue(h), ['g1', 'a1', 'a2']);
  });

  testWidgets('Play all plays the songs in page order', (tester) async {
    final (h, _) = await run(tester, 'Play all');
    expect(queue(h), ['g1', 'a1', 'a2']);
    expect(h.container.read(playerServiceProvider).queue.shuffled, isFalse);
  });

  testWidgets('Shuffle plays the songs shuffled', (tester) async {
    final (h, _) = await run(tester, 'Shuffle');
    expect(queue(h).toSet(), {'g1', 'a1', 'a2'});
    expect(h.container.read(playerServiceProvider).queue.shuffled, isTrue);
  });

  testWidgets('Add to playlist opens the picker after the row is gone', (
    tester,
  ) async {
    await run(tester, 'Add to playlist…');
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final root = Navigator.of(tester.element(dialog), rootNavigator: true);
    expect(Navigator.of(tester.element(dialog)), same(root));
  });

  testWidgets('Go to artist navigates after the row is gone', (tester) async {
    final (_, host) = await run(tester, 'Go to artist');
    expect(host.location, artistLocation('ann'));
  });

  testWidgets('Add all to Favorites saves the songs in page order', (
    tester,
  ) async {
    final (h, _) = await run(tester, 'Add all to Favorites', advanced: true);
    final paths = (await tester.runAsync(() async {
      final id = await h.db.favoritesPlaylistId();
      if (id == null) return <String>[];
      final rows =
          await (h.db.select(h.db.playlistEntries)
                ..where((e) => e.playlistId.equals(id))
                ..orderBy([(e) => OrderingTerm.asc(e.position)]))
              .get();
      return [for (final e in rows) e.path];
    }))!;
    // Stored as 0.flac (a2), 1.flac (a1), 2.flac (g1).
    expect(
      [for (final p in paths) p.substring(p.lastIndexOf('/') + 1)],
      ['2.flac', '1.flac', '0.flac'],
    );
    expect(find.text('Added to Favorites: Ann'), findsOneWidget);
  });
}
