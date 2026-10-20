import 'dart:async' show ParallelWaitError;

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/features/library/albums/albums_provider.dart';
import 'package:kanaru/features/library/library_route_keys.dart';
import 'package:logging/logging.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _tracks = [
  TestTrack('first', artist: 'Ann', album: 'Mix', year: 2001, track: 1),
  TestTrack('second', artist: 'Ann', album: 'Mix', year: 2001, track: 2),
];

const _key = AlbumKey('ann', 'mix');

void main() {
  testWidgets('the album header shows in the frame that shows the tracks', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/artists');
    goTo(tester, h, albumLocation(_key));
    // Frame by frame until the tracks are there; the header must be too.
    for (var i = 0; i < 100 && find.text('second').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('second'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);
    expect(find.text('2001 · 2 songs · 0:02'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('a failing details query shows the error, not a headless page', (
    tester,
  ) async {
    final severe = <LogRecord>[];
    final sub = Logger.root.onRecord
        .where((r) => r.level >= Level.SEVERE)
        .listen(severe.add);
    addTearDown(sub.cancel);
    // The Albums list reads the same column; keep it out of this test.
    final h = LibraryHarness(
      overrides: [albumsProvider.overrideWith((ref) => Stream.value(const []))],
    );
    await openWithTracks(tester, h, _tracks, location: '/artists');
    // The tracks query does not read this column, the details query does.
    await tester.runAsync(
      () => h.db.customStatement(
        'ALTER TABLE tracks RENAME COLUMN album_display_artist TO gone',
      ),
    );

    goTo(tester, h, albumLocation(_key));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't open the library"), findsOneWidget);
    expect(find.text('first'), findsNothing);
    expect(severe.single.message, 'Reading the album failed');
    // The database error itself, not the wrapper of the parallel reads.
    expect(severe.single.error.toString(), contains('album_display_artist'));
    expect(severe.single.error, isNot(isA<ParallelWaitError>()));
    // Leaves the page so its queries are disposed, then lets drift's
    // zero-delay stream cleanup timer run.
    goTo(tester, h, '/songs');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('an album whose tracks are all deleted shows not found', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: albumLocation(_key));
    expect(find.text('first'), findsOneWidget);

    await tester.runAsync(() async {
      final ids = [for (final t in await h.db.select(h.db.tracks).get()) t.id];
      await h.db.deleteTracksById(ids);
    });
    await tester.pumpAndSettle();

    expect(find.text('Album not found'), findsOneWidget);
    expect(find.text('first'), findsNothing);
  });
}
