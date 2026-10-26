import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:kanaru/features/player/queue/queue_save_flow.dart';
import 'package:material_ui/material_ui.dart';

import '../library/library_test_harness.dart';
import '../playlists/playlist_test_data.dart';

void main() {
  test('keeps library songs in queue order, each once', () {
    final picked = queuePlaylistPaths(
      const [
        Track(uri: '/m/a.flac', title: 'a'),
        Track(uri: '/m/b.flac', title: 'b'),
        Track(uri: '/m/a.flac', title: 'a'),
        Track(uri: 'file:///m/c.flac', title: 'c'),
        Track(uri: 'http://x/y.mp3', title: 'y'),
      ],
      {'/m/a.flac', '/m/c.flac'},
    );

    expect(picked.paths, ['/m/a.flac', '/m/c.flac']);
    expect(picked.skipped, 3);
  });

  /// Opens the header's overflow menu and picks "Save queue as playlist".
  Future<void> tapSaveInMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save queue as playlist'));
  }

  group('the queue panel button', () {
    late LibraryHarness h;

    setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

    Future<void> playAndOpenQueue(WidgetTester tester, List<Track> q) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await h.container.read(playerServiceProvider.notifier).openTracks(q);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Show now playing list'));
      await tester.pumpAndSettle();
    }

    Future<List<String>> savedPaths(WidgetTester tester) async {
      final list = await tester.runAsync(
        () => h.db.watchPlaylistSummaries().first,
      );
      return storedPaths(tester, h, list!.single.id);
    }

    testWidgets('saves the shown order under a dated default name', (
      tester,
    ) async {
      await openApp(tester, h, ['a', 'b', 'c']);
      final p = await trackPaths(tester, h);
      await playAndOpenQueue(tester, [
        Track(uri: p['c']!, title: 'c'),
        const Track(uri: '/elsewhere/x.mp3', title: 'x'),
        Track(uri: p['a']!, title: 'a'),
        Track(uri: p['c']!, title: 'c'),
      ]);

      await tapSaveInMenu(tester);
      await settleDb(tester);
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, startsWith('Queue '));
      await tester.tap(find.text('Create'));
      await settleDb(tester);

      expect(await savedPaths(tester), [p['c'], p['a']]);
      expect(find.textContaining('Saved 2 songs to Queue '), findsOneWidget);
      expect(find.textContaining('2 left out'), findsOneWidget);
    });

    testWidgets('a queue with no library song says so', (tester) async {
      await openApp(tester, h, ['a']);
      await playAndOpenQueue(tester, const [
        Track(uri: '/elsewhere/x.mp3', title: 'x'),
      ]);

      await tapSaveInMenu(tester);
      await settleDb(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Nothing in the queue is in your library'),
        findsOneWidget,
      );
    });

    testWidgets('cancelling the name dialog saves nothing', (tester) async {
      await openApp(tester, h, ['a']);
      final p = await trackPaths(tester, h);
      await playAndOpenQueue(tester, [Track(uri: p['a']!, title: 'a')]);

      await tapSaveInMenu(tester);
      await settleDb(tester);
      await tester.tap(find.text('Cancel'));
      await settleDb(tester);

      final list = await tester.runAsync(
        () => h.db.watchPlaylistSummaries().first,
      );
      expect(list, isEmpty);
    });

    testWidgets('the header fits the narrow queue page', (tester) async {
      await openApp(tester, h, ['a']);
      final p = await trackPaths(tester, h);
      tester.view.physicalSize = const Size(360, 700);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await h.container.read(playerServiceProvider.notifier).openTracks([
        Track(uri: p['a']!, title: 'a'),
      ]);
      h.container.read(nowPlayingOpenProvider.notifier).open();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NowPlayingScreen),
          matching: find.byTooltip('Show now playing list'),
        ),
      );
      await tester.pumpAndSettle();

      // Both header rows fit in 360 px.
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      expect(find.text('Save queue as playlist'), findsOneWidget);
      expect(find.byTooltip('Jump to current song'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
