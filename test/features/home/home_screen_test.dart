import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/database/play_history_writes.dart';
import 'package:kanaru/features/home/home_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'home_test_harness.dart';

const _titles = [
  'Recently played',
  'Recently added',
  'Lost memories',
  'Recent albums',
  'Recent artists',
];
const _memoriesEmpty = 'No music from this time last year';

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

  Future<void> open(
    WidgetTester tester,
    HomeHarness h, {
    double width = 1280,
    double textScale = 1,
  }) => h.pump(
    tester,
    const HomeScreen(),
    width: width,
    // Tall enough for all five sections: the page builds its rows lazily.
    height: 2400,
    textScale: textScale,
  );

  /// The card of the song at [path].
  Finder card(String path) => find.text('T $path');

  group('empty states', () {
    testWidgets('a library without songs shows the empty state', (
      tester,
    ) async {
      final h = HomeHarness();
      await open(tester, h);
      expect(find.text('Your library is empty'), findsOneWidget);
      for (final title in _titles) {
        expect(find.text(title), findsNothing);
      }
    });

    testWidgets('no database shows the empty state', (tester) async {
      final h = HomeHarness(hasDatabase: false);
      await open(tester, h);
      expect(find.text('Your library is empty'), findsOneWidget);
      expect(find.text(_titles.first), findsNothing);
    });
  });

  group('sections', () {
    testWidgets('five titles in order, no text but the memories sentence', (
      tester,
    ) async {
      final h = HomeHarness();
      await h.addTrack('/a', addedAt: daysAgo(40));
      await open(tester, h);

      final tops = [
        for (final t in _titles) tester.getTopLeft(find.text(t)).dy,
      ];
      expect([...tops]..sort(), tops, reason: 'sections run top to bottom');
      expect(find.text(_memoriesEmpty), findsOneWidget);
      // Nothing was played, so the played, memories, albums and artists rows
      // hold no card; only the added row shows its song.
      const allowed = {
        ..._titles,
        _memoriesEmpty,
        'Pick up where the music left off',
        '1 day',
        '3 days',
        '7 days',
        '30 days',
        'All',
        'T /a',
        '',
      };
      final texts = [
        for (final w in tester.widgetList<Text>(find.byType(Text))) w.data,
      ];
      for (final t in texts) {
        if (t != null && t.startsWith('Good ')) continue;
        expect(allowed, contains(t));
      }
    });

    testWidgets('a play last year fills the memories row', (tester) async {
      final h = HomeHarness();
      await h.addTrack('/a', addedAt: daysAgo(400));
      await play(h, '/a', DateTime(2025, 10, 23, 9).millisecondsSinceEpoch);
      await open(tester, h);
      expect(find.text(_memoriesEmpty), findsNothing);
      // The song also shows in the played and added rows; the
      // memories row is the one between its title and the albums title.
      final top = tester.getTopLeft(find.text('Lost memories')).dy;
      final bottom = tester.getTopLeft(find.text('Recent albums')).dy;
      final ys = [
        for (final e in card('/a').evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dy,
      ];
      expect(ys.where((y) => y > top && y < bottom), hasLength(1));
    });

    testWidgets('chips change the recently added row and stay picked', (
      tester,
    ) async {
      final h = HomeHarness();
      await h.addTrack('/new', addedAt: daysAgo(0));
      await h.addTrack('/old', addedAt: daysAgo(20));
      await open(tester, h);
      expect(card('/old'), findsNothing);

      await tester.tap(find.text('30 days'));
      await tester.pumpAndSettle();
      expect(card('/old'), findsOneWidget);

      GoRouter.of(tester.element(find.byType(HomeScreen))).go('/other');
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.text('at /other'))).go('/');
      await tester.pumpAndSettle();
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '30 days'),
      );
      expect(chip.selected, isTrue);
    });
  });

  testWidgets('a narrow window with large text does not overflow', (
    tester,
  ) async {
    final h = HomeHarness();
    await h.addTrack('/a', artist: 'Ann', album: 'Alpha', addedAt: daysAgo(0));
    await play(h, '/a', daysAgo(0));
    await open(tester, h, width: 480, textScale: 1.5);
    expect(tester.takeException(), isNull);
    expect(find.text('Recent artists'), findsOneWidget);
  });
}
