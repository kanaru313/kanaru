import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/queue/queue_tile.dart';
import 'package:kanaru/shared/song_modal/song_modal_header.dart';
import 'package:material_ui/material_ui.dart';

import '../library/library_test_harness.dart';
import '../../shared/song_modal/song_modal_test_support.dart';
import '../playlists/playlist_test_data.dart';

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  Future<void> playAndOpenQueue(WidgetTester tester, List<Track> q) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await h.container.read(playerServiceProvider.notifier).openTracks(q);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show now playing list'));
    await tester.pumpAndSettle();
  }

  Finder row(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(QueueTile));

  Future<void> openMenu(WidgetTester tester, String title) async {
    await tester.tap(row(title).last, buttons: kSecondaryButton);
    await settleDb(tester);
    await settleSongModal(tester);
  }

  testWidgets('the heart adds a library song to Favorites and takes it out', (
    tester,
  ) async {
    await openApp(tester, h, ['a', 'b']);
    final p = await trackPaths(tester, h);
    await playAndOpenQueue(tester, [
      Track(uri: p['a']!, title: 'a'),
      Track(uri: p['b']!, title: 'b'),
    ]);

    await openMenu(tester, 'b');
    expect(find.text('Remove from queue'), findsOneWidget);
    await tester.tap(find.text('Add to favorites'));
    await settleDb(tester);
    expect(await tester.runAsync(() => h.db.isFavorite(p['b']!)), isTrue);

    await openMenu(tester, 'b');
    await tester.tap(find.text('Remove from favorites'));
    await settleDb(tester);
    expect(await tester.runAsync(() => h.db.isFavorite(p['b']!)), isFalse);
  });

  testWidgets('a song outside the library has no heart', (tester) async {
    await openApp(tester, h, ['a']);
    final p = await trackPaths(tester, h);
    await playAndOpenQueue(tester, [
      Track(uri: p['a']!, title: 'a'),
      const Track(uri: '/elsewhere/x.mp3', title: 'x'),
    ]);

    await openMenu(tester, 'x');
    expect(find.text('Add to favorites'), findsNothing);
    expect(find.text('Remove from favorites'), findsNothing);
    expect(find.text('Remove from queue'), findsOneWidget);
  });

  testWidgets('remove takes the row out of the queue', (tester) async {
    await openApp(tester, h, ['a', 'b']);
    final p = await trackPaths(tester, h);
    await playAndOpenQueue(tester, [
      Track(uri: p['a']!, title: 'a'),
      Track(uri: p['b']!, title: 'b'),
    ]);

    await openMenu(tester, 'b');
    await tester.tap(find.text('Remove from queue'));
    await tester.pumpAndSettle();
    final queue = h.container.read(playerServiceProvider).queue.tracks;
    expect([for (final t in queue) t.title], ['a']);
  });

  testWidgets('Shift+F10 on a focused row opens the same menu', (tester) async {
    await openApp(tester, h, ['a', 'b']);
    final p = await trackPaths(tester, h);
    await playAndOpenQueue(tester, [
      Track(uri: p['a']!, title: 'a'),
      Track(uri: p['b']!, title: 'b'),
    ]);

    Focus.of(tester.element(find.text('b').last)).requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await settleDb(tester);
    await settleSongModal(tester);
    expect(find.text('Remove from queue'), findsOneWidget);
    expect(find.byType(SongModalHeader), findsOneWidget);
  });
}
