import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/play_history_writes.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/home/home_screen.dart';

import 'home_test_harness.dart';

void main() {
  final now = DateTime(2026, 10, 24, 12);
  int daysAgo(int days) =>
      DateTime(now.year, now.month, now.day - days, 11).millisecondsSinceEpoch;

  Future<void> play(HomeHarness h, String path, int playedAt) async {
    await h.db.insertLibraryPlay(
      path: path,
      playedAt: playedAt,
      listenedMs: 200000,
    );
  }

  Future<void> open(WidgetTester tester, HomeHarness h) =>
      h.pump(tester, const HomeScreen(), height: 2400);

  /// The card of the song at [path].
  Finder card(String path) => find.text('T $path');

  group('cards', () {
    testWidgets('tapping a played song queues the whole row from it', (
      tester,
    ) async {
      final h = HomeHarness();
      for (final (i, p) in ['/a', '/b', '/c'].indexed) {
        await h.addTrack(p, artist: 'Ann', addedAt: daysAgo(40));
        await play(h, p, daysAgo(0) + i * 1000);
      }
      await open(tester, h);

      // Newest listen first: c, b, a. The first copy of 'T /b' is on the
      // played shelf, the topmost one.
      final b = card('/b').first;
      await tester.tap(b);
      await tester.pump();
      final queue = h.container.read(playerServiceProvider).queue;
      expect([for (final t in queue.tracks) t.title], ['T /c', 'T /b', 'T /a']);
      expect(queue.current?.title, 'T /b');
    });

    testWidgets('right click on a song opens the track menu', (tester) async {
      final h = HomeHarness();
      await h.addTrack('/a', artist: 'Ann', addedAt: daysAgo(0));
      await play(h, '/a', daysAgo(0));
      await open(tester, h);
      await tester.tap(card('/a').first, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text('Play next'), findsOneWidget);
      expect(find.text('Add to queue'), findsOneWidget);
      expect(find.text('Show artist'), findsOneWidget);
    });

    testWidgets('an album card opens the album page and has a menu', (
      tester,
    ) async {
      final h = HomeHarness();
      await h.addTrack('/a', artist: 'Ann', album: 'Alpha');
      await play(h, '/a', daysAgo(0));
      await open(tester, h);

      await tester.tap(find.text('Alpha'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text('Play next'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(find.textContaining('at /albums/'), findsOneWidget);
    });

    testWidgets('an artist card shows its song count and opens the page', (
      tester,
    ) async {
      final h = HomeHarness();
      await h.addTrack('/a', artist: 'Ann', album: 'Alpha');
      await h.addTrack('/b', artist: 'Ann', album: 'Alpha');
      await play(h, '/a', daysAgo(0));
      await open(tester, h);

      expect(find.text('2 songs'), findsOneWidget);
      await tester.tap(find.text('Ann').last, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text('Add to queue'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('2 songs'));
      await tester.pumpAndSettle();
      expect(find.textContaining('at /artists/'), findsOneWidget);
    });
  });
}
