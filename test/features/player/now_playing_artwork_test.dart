import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/original_cover_reader.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:kanaru/features/player/now_playing/now_playing_track_column.dart';
import 'package:kanaru/features/player/now_playing_summary.dart';
import 'package:kanaru/features/player/track_artwork.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_original_cover_reader.dart';
import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  late LibraryHarness h;
  late FakeOriginalCoverReader reader;
  late List<String> paths;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 2; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
    }
  }

  /// The app at [size] with library tracks a and b; [paths] are theirs.
  Future<void> launch(WidgetTester tester, Size size) async {
    reader = FakeOriginalCoverReader();
    h = LibraryHarness(
      overrides: [originalCoverReaderProvider.overrideWithValue(reader)],
    );
    await openWithTracks(tester, h, [
      const TestTrack('a'),
      const TestTrack('b'),
    ], location: '/albums');
    tester.view.physicalSize = size;
    final found = (await tester.runAsync(
      () => h.db.select(h.db.tracks).get(),
    ))!;
    paths = (found..sort((x, y) => x.title.compareTo(y.title)))
        .map((t) => t.path)
        .toList();
  }

  Future<void> play(WidgetTester tester, int index) async {
    await h.container.read(playerServiceProvider.notifier).openTracks([
      Track(uri: paths[index], title: 'track'),
    ]);
    await settle(tester);
  }

  Future<void> openNowPlaying(WidgetTester tester) async {
    h.container.read(nowPlayingOpenProvider.notifier).open();
    await tester.pumpAndSettle();
  }

  TrackArtwork artIn(WidgetTester tester, Finder scope) =>
      tester.widget<TrackArtwork>(
        find.descendant(of: scope, matching: find.byType(TrackArtwork)),
      );

  final footer = find.byType(NowPlayingSummary);
  final screen = find.byType(NowPlayingScreen);

  /// The cover of the playing track: in a wide window the queue beside it
  /// has covers of its own.
  Finder coverScope() => find.byType(NowPlayingTrackColumn).evaluate().isEmpty
      ? screen
      : find.byType(NowPlayingTrackColumn);

  for (final (name, size) in [
    ('wide', const Size(1280, 800)),
    ('narrow', const Size(600, 700)),
  ]) {
    testWidgets(
      '$name Now Playing shows the original cover, the bar does not',
      (tester) async {
        await launch(tester, size);
        reader.bytes[paths[0]] = Uint8List.fromList(_png);
        await play(tester, 0);
        // The bar is under Now Playing once that is open.
        expect(artIn(tester, footer).original, isNull);
        expect(artIn(tester, footer).layered, isFalse);
        await openNowPlaying(tester);

        expect(artIn(tester, coverScope()).layered, isTrue);
        expect(artIn(tester, coverScope()).original?.uri, paths[0]);
        expect(reader.reads, [paths[0]]);
      },
    );
  }

  testWidgets('the original of the previous track is never handed on', (
    tester,
  ) async {
    await launch(tester, const Size(1280, 800));
    final slow = Completer<Uint8List?>();
    reader.pending[paths[0]] = slow;
    reader.bytes[paths[1]] = Uint8List.fromList(_png);

    await play(tester, 0);
    await openNowPlaying(tester);
    await play(tester, 1);
    slow.complete(Uint8List.fromList(_png));
    await settle(tester);

    expect(artIn(tester, coverScope()).original?.uri, paths[1]);
  });

  testWidgets('a track without an original shows only its thumbnail', (
    tester,
  ) async {
    await launch(tester, const Size(1280, 800));

    await play(tester, 0);
    await openNowPlaying(tester);

    expect(artIn(tester, coverScope()).original, isNull);
  });
}
