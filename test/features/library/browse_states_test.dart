import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/tag_reader.dart';
import 'package:kanaru/features/library/albums/album_grid_tile.dart';
import 'package:kanaru/features/library/albums/album_tracks_provider.dart';
import 'package:kanaru/features/library/albums/albums_provider.dart';
import 'package:kanaru/features/library/artists/artist_tracks_provider.dart';
import 'package:kanaru/features/library/library_route_keys.dart';
import 'package:logging/logging.dart';

import '../../core/indexer/fake_tag_reader.dart';
import 'browse_test_data.dart';
import 'library_test_harness.dart';

/// A tag reader that waits for [release], to look at a scan in progress.
class _GatedTagReader extends FakeTagReader {
  final release = Completer<void>();

  @override
  Future<List<TrackTags>> readBatch(List<String> paths) async {
    await release.future;
    return super.readBatch(paths);
  }
}

const _key = AlbumKey('ann', 'x');

BrowseTrack _track(String title) => BrowseTrack(
  id: title.hashCode,
  path: '/$title',
  title: title,
  artist: 'Ann',
  album: 'X',
  albumKey: _key,
);

AlbumSummary _album(String title) => AlbumSummary(
  key: AlbumKey('ann', title.toLowerCase()),
  title: title,
  artist: 'Ann',
  trackCount: 1,
  addedAt: 1,
);

/// Opens [location] without waiting for it to settle: its stream is fed by
/// the test, and the spinner animates until then.
Future<void> _open(
  WidgetTester tester,
  LibraryHarness h,
  String location,
) async {
  await insertTracks(tester, h, const []);
  await h.pump(tester, hasRoots: true);
  goTo(tester, h, location);
  await tester.pump();
}

void main() {
  /// Severe log records during the test.
  List<LogRecord> captureSevere() {
    final records = <LogRecord>[];
    final sub = Logger.root.onRecord
        .where((r) => r.level >= Level.SEVERE)
        .listen(records.add);
    addTearDown(sub.cancel);
    return records;
  }

  testWidgets('a failed reload of a page keeps its tracks and is logged', (
    tester,
  ) async {
    final severe = captureSevere();
    final tracks = StreamController<List<BrowseTrack>>();
    addTearDown(tracks.close);
    final h = LibraryHarness(
      overrides: [
        albumTracksProvider.overrideWith((ref, key) => tracks.stream),
      ],
    );
    await _open(tester, h, albumLocation(_key));
    tracks.add([_track('first')]);
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);

    tracks.addError(StateError('disk gone'));
    await tester.pumpAndSettle();

    expect(find.text('first'), findsOneWidget);
    expect(find.text("Couldn't open the library"), findsNothing);
    expect(severe.single.message, 'Reading the album failed');
  });

  testWidgets('a page that fails before any result says so and logs', (
    tester,
  ) async {
    final severe = captureSevere();
    final h = LibraryHarness(
      overrides: [
        artistTracksProvider.overrideWith(
          (ref, key) => Stream.error(StateError('boom')),
        ),
      ],
    );
    await openWithTracks(tester, h, const [], location: artistLocation('ann'));
    expect(find.text("Couldn't open the library"), findsOneWidget);
    expect(severe.single.message, 'Reading the artist failed');
  });

  testWidgets('a failed reload of the albums keeps the grid', (tester) async {
    final severe = captureSevere();
    final albums = StreamController<List<AlbumSummary>>();
    addTearDown(albums.close);
    final h = LibraryHarness(
      overrides: [albumsProvider.overrideWith((ref) => albums.stream)],
    );
    await _open(tester, h, '/albums');
    albums.add([_album('Alpha')]);
    await tester.pumpAndSettle();
    albums.addError(StateError('boom'));
    await tester.pumpAndSettle();

    expect(find.byType(AlbumGridTile), findsOneWidget);
    expect(severe, hasLength(1));
  });

  testWidgets('pages say the library is unavailable without a database', (
    tester,
  ) async {
    final h = LibraryHarness(hasDatabase: false);
    await h.pump(tester);
    for (final location in [albumLocation(_key), artistLocation('ann')]) {
      h.container.read(routerProvider).go(location);
      await tester.pumpAndSettle();
      expect(find.text("Couldn't open the library"), findsOneWidget);
      expect(find.text('Album not found'), findsNothing);
      expect(find.text('Artist not found'), findsNothing);
    }
  });

  testWidgets('albums stay blank while the first scan has found none', (
    tester,
  ) async {
    final gated = _GatedTagReader();
    final h = LibraryHarness(reader: gated);
    final music = h.folder('music');
    h.touch(music, 'a.mp3');
    await tester.runAsync(() => h.db.addRoots([music], now: 1));
    await h.pump(tester, hasRoots: true);
    goTo(tester, h, '/albums');
    await tester.pumpAndSettle();
    expect(find.text('No albums yet'), findsOneWidget);

    unawaited(h.container.read(libraryIndexerProvider.notifier).scan());
    await waitForScanReading(tester, h);
    expect(find.text('No albums yet'), findsNothing);
    expect(find.byType(AlbumGridTile), findsNothing);

    gated.release.complete();
    await settleIo(tester, h);
  });
}
