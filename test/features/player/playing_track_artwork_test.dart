import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:kanaru/features/player/now_playing_summary.dart';
import 'package:kanaru/features/player/track_artwork.dart';
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
    // The seek bar's wave never settles while music plays.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
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
  Future<void> writeCover(WidgetTester tester, String path) async {
    await tester.runAsync(() async {
      await h.db.customStatement(
        'UPDATE tracks SET cover_key = ? WHERE path = ?',
        [fakeCoverKey('a'), path],
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
    expect(artIn(tester, screen), isNull);

    await writeCover(tester, path);
    expect(artIn(tester, screen), _cover);
  });

  testWidgets('narrow Now Playing shows a cover made while playing', (
    tester,
  ) async {
    final path = await playUncovered(tester, const Size(600, 700));
    await openNowPlaying(tester);
    expect(artIn(tester, screen), isNull);

    await writeCover(tester, path);
    expect(artIn(tester, screen), _cover);
  });

  testWidgets('a track outside the library shows its own art', (tester) async {
    await playUncovered(tester, const Size(1280, 800));
    await h.container.read(playerServiceProvider.notifier).openTracks([
      const Track(uri: '/elsewhere/x.mp3', title: 'x', artUri: '/x.jpg'),
    ]);
    await settle(tester);
    expect(artIn(tester, footer), '/x.jpg');
  });
}
