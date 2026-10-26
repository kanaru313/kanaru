import 'dart:math';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart'
    show AlbumKey, TracksCompanion;
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/library/albums/album_grid_tile.dart';
import 'package:kanaru/features/library/genres/genre_page_data.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/playlist_cover.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/stats/gated_query_interceptor.dart';
import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _tracks = [
  TestTrack('b', genre: 'Rock', album: 'Mixed', albumArtist: 'X'),
  TestTrack('a', genre: 'rock', album: 'Only', albumArtist: 'X'),
  TestTrack('c', genre: 'Rock; Pop'),
  TestTrack('j', genre: 'Jazz', album: 'Mixed', albumArtist: 'X'),
];

final _rock = genreLocation('rock');

Finder _albumTile(String title) => find.widgetWithText(AlbumGridTile, title);

void main() {
  Finder onPage(String text) => find.descendant(
    of: find.byType(CustomScrollView),
    matching: find.text(text),
  );

  List<String> queued(LibraryHarness h) => [
    for (final t in h.container.read(playerServiceProvider).queue.original)
      t.title,
  ];

  testWidgets('shows the albums and the songs of the genre', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);

    expect(find.text('2 albums · 3 songs'), findsOneWidget);
    expect(onPage('Albums'), findsOneWidget);
    expect(find.byType(AlbumGridTile), findsNWidgets(2));
    expect(_albumTile('Mixed'), findsOneWidget);
    expect(_albumTile('Only'), findsOneWidget);
    expect(find.text('Rock'), findsOneWidget, reason: 'header name');
    expect(find.text('j'), findsNothing, reason: 'a Jazz song');
    expect(find.byType(PlaylistCover), findsOneWidget);
  });

  testWidgets('a song plays the songs from it; Play from the top', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);

    await tester.tap(find.text('b').last);
    await tester.pump();
    expect(queued(h), ['a', 'b', 'c']);
    expect(h.container.read(playerServiceProvider).queue.current?.title, 'b');

    await h.container.read(playerServiceProvider.notifier).openTracks([
      Track.fromPath('/other.mp3'),
    ]);
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();
    expect(queued(h), ['a', 'b', 'c']);
    expect(h.container.read(playerServiceProvider).queue.current?.title, 'a');
  });

  testWidgets('Shuffle queues the songs shuffled', (tester) async {
    final h = LibraryHarness(
      overrides: [
        playerServiceProvider.overrideWith(
          () => PlayerService(random: Random(3)),
        ),
      ],
    );
    await openWithTracks(tester, h, _tracks, location: _rock);

    await tester.tap(find.widgetWithText(FilledButton, 'Shuffle'));
    await tester.pump();

    expect(queued(h), ['a', 'b', 'c']);
    expect(h.container.read(playerServiceProvider).queue.shuffled, isTrue);
  });

  testWidgets('an album opens in the Albums branch', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);

    await tester.tap(_albumTile('Only'));
    await tester.pumpAndSettle();

    expect(location(h), albumLocation(const AlbumKey('x', 'only')));
  });

  testWidgets('an album shows all its tracks, not only the genre ones', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);

    await tester.tap(_albumTile('Mixed'));
    await tester.pumpAndSettle();

    expect(find.text('j'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('a broken key or unknown genre shows not found', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/genres/%21%21');
    expect(find.text('Genre not found'), findsOneWidget);

    goTo(tester, h, genreLocation('nobody'));
    await tester.pumpAndSettle();
    expect(find.text('Genre not found'), findsOneWidget);
  });

  testWidgets('a genre retagged away shows not found after the refresh', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: genreLocation('jazz'));
    expect(find.text('j'), findsOneWidget);

    await tester.runAsync(
      () => (h.db.update(h.db.tracks)..where((t) => t.title.equals('j'))).write(
        const TracksCompanion(genre: Value('Blues')),
      ),
    );
    await settleIo(tester, h);

    expect(find.text('Genre not found'), findsOneWidget);
  });

  testWidgets('leaving the page disposes its query', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);
    expect(h.container.exists(genrePageProvider('rock')), isTrue);

    goTo(tester, h, '/genres');
    await tester.pumpAndSettle();
    expect(h.container.exists(genrePageProvider('rock')), isFalse);
    // Lets drift's zero-delay stream cleanup timer run.
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('albums are listed by title', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('1', genre: 'Rock', album: 'Zulu', albumArtist: 'X'),
      TestTrack('2', genre: 'Rock', album: 'alpha', albumArtist: 'X'),
      TestTrack('3', genre: 'Rock', album: 'Mid', albumArtist: 'X'),
    ], location: _rock);

    double left(String title) => tester.getTopLeft(_albumTile(title)).dx;
    expect(left('alpha'), lessThan(left('Mid')));
    expect(left('Mid'), lessThan(left('Zulu')));
  });

  testWidgets('a refresh groups the genres once, for the list and the page', (
    tester,
  ) async {
    final gate = GatedQueryInterceptor();
    final h = LibraryHarness(interceptor: gate);
    await openWithTracks(tester, h, _tracks, location: '/genres');
    goTo(tester, h, _rock);
    await tester.pumpAndSettle();
    final groupings = gate.count('GROUP BY genre');
    expect(groupings, greaterThan(0));

    await insertTracks(tester, h, const [TestTrack('z', genre: 'Rock')]);
    await settleIo(tester, h);

    await tester.scrollUntilVisible(
      find.text('z'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('z'), findsOneWidget);
    expect(gate.count('GROUP BY genre') - groupings, 1);
  });

  testWidgets('a new spelling of the genre joins the open page', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);
    expect(find.text('z'), findsNothing);

    await insertTracks(tester, h, const [TestTrack('z', genre: 'ROCK')]);
    await settleIo(tester, h);

    await tester.scrollUntilVisible(
      find.text('z'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('z'), findsOneWidget);
    expect(find.text('2 albums · 4 songs'), findsOneWidget);
  });

  testWidgets('back and forward move between Genres and a genre page', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/genres');

    await tester.tap(find.text('Jazz'));
    await tester.pumpAndSettle();
    expect(location(h), genreLocation('jazz'));

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(location(h), '/genres');

    await tester.tap(find.byTooltip('Forward'));
    await tester.pumpAndSettle();
    expect(location(h), genreLocation('jazz'));
    expect(find.text('j'), findsOneWidget);
  });
}
