import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';

import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import '../playlists/playlist_test_data.dart';
import 'queue_tile_menu_test_support.dart';

const _library = [
  TestTrack('a', artist: 'Ann', album: 'Al'),
  TestTrack('b', artist: 'Ann', album: 'Al'),
  TestTrack('c', artist: 'Ann', album: 'Al'),
  TestTrack('d', artist: 'Ann', album: 'Al'),
];

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  PlayerService player() => h.container.read(playerServiceProvider.notifier);

  Future<Map<String, String>> open(
    WidgetTester tester, [
    List<Track> extra = const [],
  ]) async {
    await openWithTracks(tester, h, _library, location: '/home');
    final p = await trackPaths(tester, h);
    await playAndOpenQueue(tester, h, [
      for (final t in ['a', 'b', 'c', 'd']) Track(uri: p[t]!, title: t),
      ...extra,
    ]);
    return p;
  }

  Future<void> pick(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await settleDb(tester);
  }

  testWidgets('Play next hands the moved track to the engine as next', (
    tester,
  ) async {
    await open(tester);
    await openQueueMenu(tester, 'd');
    await pick(tester, 'Play next');

    expect(queueTitles(h), ['a', 'd', 'b', 'c']);
    expect(h.backend.next?.title, 'd');
  });

  testWidgets('Play next from a played row lands after the playing song', (
    tester,
  ) async {
    await open(tester);
    await player().jump(2);
    await tester.pumpAndSettle();
    final calls = h.backend.calls.length;
    await openQueueMenu(tester, 'a');
    await pick(tester, 'Play next');

    expect(queueTitles(h), ['b', 'c', 'a', 'd']);
    expect(player().upNextRun, 1);
    expect(h.container.read(playerServiceProvider).queue.current?.title, 'c');
    expect(h.backend.next?.title, 'a');
    expect(
      h.backend.calls.skip(calls).where((c) => c.startsWith('open')),
      isEmpty,
      reason: 'the playing song is not reopened',
    );
  });

  testWidgets('Add to favorites says so when a rescan dropped the song', (
    tester,
  ) async {
    final p = await open(tester);
    await openQueueMenu(tester, 'b');
    await tester.runAsync(() => h.db.delete(h.db.tracks).go());
    await pick(tester, 'Add to favorites');

    expect(find.text('This song is no longer in the library'), findsOneWidget);
    expect(await tester.runAsync(() => h.db.isFavorite(p['b']!)), isFalse);
  });

  testWidgets('Remove from favorites works on a song outside the library', (
    tester,
  ) async {
    await open(tester, const [Track(uri: '/elsewhere/x.mp3', title: 'x')]);
    await tester.runAsync(
      () => h.db.setFavorite('/elsewhere/x.mp3', favorite: true, now: 1),
    );
    await openQueueMenu(tester, 'x');
    await pick(tester, 'Remove from favorites');

    expect(
      await tester.runAsync(() => h.db.isFavorite('/elsewhere/x.mp3')),
      isFalse,
    );
  });
}
