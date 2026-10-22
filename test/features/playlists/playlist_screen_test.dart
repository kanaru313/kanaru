import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/playlists/playlist_page_data.dart';
import 'package:material_ui/material_ui.dart';

import '../library/browse_test_data.dart' show goTo;
import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  testWidgets('shows the name, count and entries in order', (tester) async {
    await openMix(tester, h);

    expect(find.text('4 songs'), findsOneWidget);
    expect(shownTitles(tester), mixTitles);
  });

  testWidgets('a drag is saved, never flickers back and survives a reload', (
    tester,
  ) async {
    final id = await openMix(tester, h);
    final paths = await trackPaths(tester, h);
    await dragFirstRowDown(tester);

    // Every frame until the move is stored and the page reloaded from it.
    const moved = ['Bravo', 'Charlie', 'Alpha', 'Delta'];
    final frames = <List<String>>[];
    await pumpUntil(
      tester,
      () async =>
          [for (final e in (await h.db.playlistPage(id))!.entries) e.path]
              .join() ==
          [for (final t in moved) paths[t]].join(),
      onFrame: () => frames.add(shownTitles(tester)),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      frames.add(shownTitles(tester));
    }
    await settleDb(tester);

    expect(shownTitles(tester), moved);
    final first = frames.indexWhere((f) => f.join() == moved.join());
    expect(first, isNot(-1), reason: 'the new order appeared');
    expect(
      frames.skip(first).every((f) => f.join() == moved.join()),
      isTrue,
      reason: 'the old order came back for a frame: $frames',
    );
    expect(await storedPaths(tester, h, id), [for (final t in moved) paths[t]]);

    h.container.invalidate(playlistPageProvider(id));
    await settleDb(tester);
    expect(shownTitles(tester), moved);
  });

  testWidgets('removing a row keeps the positions dense', (tester) async {
    final id = await openMix(tester, h);

    await tester.tap(find.byTooltip('Remove from playlist').at(1));
    await settleDb(tester);

    expect(shownTitles(tester), ['Alpha', 'Charlie', 'Delta']);
    final stored = await tester.runAsync(
      () => h.db.select(h.db.playlistEntries).get(),
    );
    expect(stored!.map((e) => e.position).toList()..sort(), [0, 1, 2]);
    expect(stored.every((e) => e.playlistId == id), isTrue);
    expect(find.text('3 songs'), findsOneWidget);
  });

  testWidgets('an entry without a track says so and is skipped on play', (
    tester,
  ) async {
    await openApp(tester, h, mixTitles);
    final paths = await trackPaths(tester, h);
    final id = await tester.runAsync(
      () => h.db.createPlaylist(
        'Mix',
        now: 1,
        paths: [paths['Alpha']!, '/gone/lost.mp3', paths['Charlie']!],
      ),
    );
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);

    expect(find.text('Not in library'), findsOneWidget);

    await tester.tap(find.text('Charlie'));
    await tester.pumpAndSettle();

    final queue = h.container.read(playerServiceProvider).queue;
    expect([for (final t in queue.original) t.title], ['Alpha', 'Charlie']);
    expect(queue.index, 1);
    expect(h.backend.calls.last, startsWith('open(Charlie'));
  });

  testWidgets('Play starts from the first song that can play', (tester) async {
    await openApp(tester, h, mixTitles);
    final paths = await trackPaths(tester, h);
    final id = await tester.runAsync(
      () => h.db.createPlaylist(
        'Mix',
        now: 1,
        paths: ['/gone/lost.mp3', paths['Bravo']!, paths['Delta']!],
      ),
    );
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pumpAndSettle();

    final queue = h.container.read(playerServiceProvider).queue;
    expect([for (final t in queue.original) t.title], ['Bravo', 'Delta']);
    expect(queue.index, 0);
  });

  testWidgets('an empty playlist explains how to fill it', (tester) async {
    await openApp(tester, h, mixTitles);
    final id = await seedPlaylist(tester, h, 'Empty', const []);
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);

    expect(find.text('This playlist is empty'), findsOneWidget);
  });
}
