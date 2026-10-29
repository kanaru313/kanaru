import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';

import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import '../playlists/playlist_test_data.dart';
import 'queue_tile_menu_test_support.dart';

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  Future<Map<String, String>> open(
    WidgetTester tester,
    List<Track> Function(Map<String, String> paths) queue,
  ) async {
    await openWithTracks(tester, h, const [
      TestTrack('a', artist: 'Ann', album: 'Al'),
      TestTrack('b', artist: 'Ann', album: 'Al'),
      TestTrack('c', artist: 'Ann', album: 'Al'),
    ], location: '/home');
    final p = await trackPaths(tester, h);
    await playAndOpenQueue(tester, h, queue(p));
    return p;
  }

  Track lib(Map<String, String> p, String t) => Track(uri: p[t]!, title: t);

  testWidgets('a library row shows every row in order', (tester) async {
    await open(tester, (p) => [lib(p, 'a'), lib(p, 'b'), lib(p, 'c')]);
    await openQueueMenu(tester, 'c');
    expect(menuLabels(tester, allMenuLabels), [
      'Play next',
      'Add to playlist…',
      'Add to favorites',
      'Find lyrics online…',
      'Show artist',
      'Show album',
      'Show in folder',
      'Show in file manager',
      'Remove from queue',
    ]);
  });

  testWidgets('a local file outside the library has no library rows', (
    tester,
  ) async {
    await open(
      tester,
      (p) => [lib(p, 'a'), const Track(uri: '/elsewhere/x.mp3', title: 'x')],
    );
    await openQueueMenu(tester, 'x');
    expect(menuLabels(tester, allMenuLabels), [
      'Play next',
      'Find lyrics online…',
      'Show in file manager',
      'Remove from queue',
    ]);
  });

  testWidgets('a titled local file outside the library can find lyrics', (
    tester,
  ) async {
    await open(
      tester,
      (p) => [
        lib(p, 'a'),
        const Track(uri: '/elsewhere/x.mp3', title: 'Real title'),
      ],
    );
    await openQueueMenu(tester, 'Real title');
    expect(menuLabels(tester, allMenuLabels), [
      'Play next',
      'Find lyrics online…',
      'Show in file manager',
      'Remove from queue',
    ]);
  });

  testWidgets('an untagged local file can find lyrics', (tester) async {
    await open(
      tester,
      (p) => [lib(p, 'a'), const Track(uri: '/elsewhere/x.mp3', title: 'x')],
    );
    await openQueueMenu(tester, 'x');
    expect(menuLabels(tester, allMenuLabels), contains('Find lyrics online…'));

    // The dialog's cache key is scoped to the track, so two untagged songs
    // of the same length do not share rejects.
    const same = Duration(seconds: 200);
    final one = LyricsTarget.fromTrack(
      const Track(uri: '/elsewhere/x.mp3', title: 'x', duration: same),
    );
    final other = LyricsTarget.fromTrack(
      const Track(uri: '/elsewhere/y.mp3', title: 'y', duration: same),
    );
    expect(one.query.title, isNull);
    expect(one.cacheKey, isNot(other.cacheKey));
  });

  testWidgets('a favorite outside the library can be taken out', (
    tester,
  ) async {
    await open(
      tester,
      (p) => [lib(p, 'a'), const Track(uri: '/elsewhere/x.mp3', title: 'x')],
    );
    await tester.runAsync(
      () => h.db.setFavorite('/elsewhere/x.mp3', favorite: true, now: 1),
    );
    await openQueueMenu(tester, 'x');
    expect(menuLabels(tester, allMenuLabels), [
      'Play next',
      'Remove from favorites',
      'Find lyrics online…',
      'Show in file manager',
      'Remove from queue',
    ]);
  });

  testWidgets('a stream has no file manager row', (tester) async {
    await open(
      tester,
      (p) => [
        lib(p, 'a'),
        const Track(uri: 'https://x.test/s.mp3', title: 's'),
      ],
    );
    await openQueueMenu(tester, 's');
    expect(menuLabels(tester, allMenuLabels), [
      'Play next',
      'Remove from queue',
    ]);
  });

  testWidgets('the playing row and a play next row have no Play next', (
    tester,
  ) async {
    await open(tester, (p) => [lib(p, 'a'), lib(p, 'b'), lib(p, 'c')]);
    await openQueueMenu(tester, 'a');
    expect(menuLabels(tester, allMenuLabels), isNot(contains('Play next')));
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();

    await h.container.read(playerServiceProvider.notifier).moveToPlayNext(2);
    await tester.pumpAndSettle();
    await openQueueMenu(tester, 'c');
    expect(menuLabels(tester, allMenuLabels), isNot(contains('Play next')));
  });

  testWidgets('a played row still offers Play next', (tester) async {
    await open(tester, (p) => [lib(p, 'a'), lib(p, 'b'), lib(p, 'c')]);
    await h.container.read(playerServiceProvider.notifier).jump(2);
    await tester.pumpAndSettle();
    await openQueueMenu(tester, 'a');
    expect(menuLabels(tester, allMenuLabels), contains('Play next'));
  });

  testWidgets('Show album is enabled from the library row, not the snapshot', (
    tester,
  ) async {
    // A restored queue holds tracks without their album.
    await open(tester, (p) => [lib(p, 'a'), lib(p, 'b')]);
    await openQueueMenu(tester, 'b');
    expect(menuRowEnabled(tester, 'Show album'), isTrue);
    expect(menuRowEnabled(tester, 'Show artist'), isTrue);
  });
}
