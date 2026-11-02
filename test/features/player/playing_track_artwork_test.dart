import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:kanaru/features/player/now_playing/now_playing_track_column.dart';
import 'package:kanaru/features/player/now_playing_summary.dart';
import 'package:kanaru/features/player/queue/queue_sheet_host.dart';
import 'package:kanaru/features/player/queue/queue_tile.dart';
import 'package:kanaru/features/player/track_artwork.dart';
import 'package:kanaru/shared/widgets/song_row_view.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/indexer/fake_tag_reader.dart';
import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';

const _covers = '/cache/kanaru/covers/512';
final _cover = '$_covers/${fakeCoverKey('a')}';

void main() {
  late LibraryHarness h;

  /// Lets the database answer, then settles the UI.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 2; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
    }
  }

  /// The app at [size] with one library track without a cover, playing.
  /// Returns the track's path.
  Future<String> playUncovered(WidgetTester tester, Size size) async {
    h = LibraryHarness(coverCacheDirectory: _covers);
    await openWithTracks(tester, h, [
      const TestTrack('a'),
    ], location: '/albums');
    tester.view.physicalSize = size;
    final path = (await tester.runAsync(
      () => h.db.select(h.db.tracks).map((t) => t.path).getSingle(),
    ))!;
    await h.container.read(playerServiceProvider.notifier).openTracks([
      Track(uri: path, title: 'a'),
    ]);
    await settle(tester);
    return path;
  }

  /// Writes the track's cover, as the cover pass does, then settles.
  /// [key] defaults to the cover key of track 'a'; pass `null` to remove it.
  Future<void> writeCover(
    WidgetTester tester,
    String path, [
    String? key = 'a',
  ]) async {
    await tester.runAsync(() async {
      await h.db.customStatement(
        'UPDATE tracks SET cover_key = ? WHERE path = ?',
        [key == null ? null : fakeCoverKey(key), path],
      );
      h.db.notifyUpdates({
        const TableUpdate('tracks', kind: UpdateKind.update),
      });
    });
    await settle(tester);
  }

  String? artIn(WidgetTester tester, Finder scope) => tester
      .widget<TrackArtwork>(
        find.descendant(of: scope, matching: find.byType(TrackArtwork)),
      )
      .artUri;

  Future<void> openNowPlaying(WidgetTester tester) async {
    h.container.read(nowPlayingOpenProvider.notifier).open();
    await tester.pumpAndSettle();
  }

  final footer = find.byType(NowPlayingSummary);
  final screen = find.byType(NowPlayingScreen);

  /// The cover of the playing track: in a wide window the queue beside it
  /// has covers of its own.
  Finder coverScope() => find.byType(NowPlayingTrackColumn).evaluate().isEmpty
      ? screen
      : find.byType(NowPlayingTrackColumn);

  testWidgets('the player bar shows a cover made while playing', (
    tester,
  ) async {
    final path = await playUncovered(tester, const Size(1280, 800));
    expect(artIn(tester, footer), isNull);

    await writeCover(tester, path);
    expect(artIn(tester, footer), _cover);
  });

  testWidgets('wide Now Playing shows a cover made while playing', (
    tester,
  ) async {
    final path = await playUncovered(tester, const Size(1280, 800));
    await openNowPlaying(tester);
    expect(artIn(tester, coverScope()), isNull);

    await writeCover(tester, path);
    expect(artIn(tester, coverScope()), _cover);
  });

  testWidgets('narrow Now Playing shows a cover made while playing', (
    tester,
  ) async {
    final path = await playUncovered(tester, const Size(600, 700));
    await openNowPlaying(tester);
    expect(artIn(tester, coverScope()), isNull);

    await writeCover(tester, path);
    expect(artIn(tester, coverScope()), _cover);
  });

  testWidgets('a track outside the library shows its own art', (tester) async {
    await playUncovered(tester, const Size(1280, 800));
    await h.container.read(playerServiceProvider.notifier).openTracks([
      const Track(uri: '/elsewhere/x.mp3', title: 'x', artUri: '/x.jpg'),
    ]);
    await settle(tester);
    expect(artIn(tester, footer), '/x.jpg');
  });

  /// The cover the queue row at [index] draws.
  String? rowArt(WidgetTester tester, int index) => tester
      .widget<SongRowView>(
        find.descendant(
          of: find.byType(QueueTile).at(index),
          matching: find.byType(SongRowView),
        ),
      )
      .coverPath;

  Future<void> openQueue(WidgetTester tester) async {
    QueueSheetHost.of(tester.element(footer)).open();
    await tester.pumpAndSettle();
  }

  testWidgets('a queue row shows a cover made while playing', (tester) async {
    final path = await playUncovered(tester, const Size(1280, 800));
    await openQueue(tester);
    expect(rowArt(tester, 0), isNull);

    await writeCover(tester, path);
    expect(rowArt(tester, 0), _cover);
  });

  Future<String> playQueuedWithArt(WidgetTester tester) async {
    final path = await playUncovered(tester, const Size(1280, 800));
    await writeCover(tester, path);
    await h.container.read(playerServiceProvider.notifier).openTracks([
      Track(uri: path, title: 'a', artUri: _cover),
    ]);
    await settle(tester);
    await openQueue(tester);
    expect(rowArt(tester, 0), _cover);
    return path;
  }

  testWidgets('a queue row follows a replaced cover', (tester) async {
    final path = await playQueuedWithArt(tester);

    await writeCover(tester, path, 'b');
    expect(rowArt(tester, 0), '$_covers/${fakeCoverKey('b')}');
  });

  testWidgets('a queue row drops a removed cover', (tester) async {
    final path = await playQueuedWithArt(tester);

    await writeCover(tester, path, null);
    expect(rowArt(tester, 0), isNull);
  });

  testWidgets('a queue row of a track outside the library keeps its own art', (
    tester,
  ) async {
    await playUncovered(tester, const Size(1280, 800));
    await h.container.read(playerServiceProvider.notifier).openTracks([
      const Track(uri: '/elsewhere/x.mp3', title: 'x', artUri: '/art/x.jpg'),
    ]);
    await settle(tester);
    await openQueue(tester);
    expect(rowArt(tester, 0), '/art/x.jpg');
  });
}
