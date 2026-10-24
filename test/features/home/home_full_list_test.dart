import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/database/home_windows.dart';
import 'package:kanaru/core/database/play_history_writes.dart';
import 'package:kanaru/features/home/home_paged_providers.dart';
import 'package:kanaru/features/home/home_providers.dart';
import 'package:kanaru/features/home/home_routes.dart';
import 'package:kanaru/features/home/home_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'home_test_harness.dart';

void main() {
  final now = DateTime(2026, 10, 24, 12);
  int daysAgo(int days) =>
      DateTime(now.year, now.month, now.day - days, 11).millisecondsSinceEpoch;

  final routes = [
    GoRoute(
      path: '/home',
      builder: (_, _) => const HomeScreen(),
      routes: homeRoutes,
    ),
    GoRoute(path: '/history', builder: (_, _) => const Text('at history')),
  ];

  /// Where the router is. A page swapped in by `replace` keeps its own
  /// location in the match, while the list's `uri` still names the page it
  /// replaced.
  String location(HomeHarness h) {
    final configuration = h.router.routerDelegate.currentConfiguration;
    final last = configuration.last;
    return (last is ImperativeRouteMatch ? last.matches : configuration).uri
        .toString();
  }

  Future<void> open(
    WidgetTester tester,
    HomeHarness h,
    String at, {
    double height = 2400,
  }) => h.pump(
    tester,
    const SizedBox(),
    height: height,
    routes: routes,
    initialLocation: at,
  );

  Future<void> addTracks(
    HomeHarness h,
    int count, {
    int Function(int i)? addedAt,
  }) async {
    for (var i = 0; i < count; i++) {
      await h.addTrack(
        '/m/$i.mp3',
        addedAt: addedAt?.call(i) ?? now.millisecondsSinceEpoch - i * 1000,
      );
    }
  }

  group('see all', () {
    testWidgets('each button opens its list', (tester) async {
      final h = HomeHarness(now: now);
      await addTracks(h, 1);
      await open(tester, h, '/home');
      final buttons = find.byTooltip('See all');
      expect(buttons, findsNWidgets(5));

      const expected = [
        '/history',
        '/home/recently-added?window=1d',
        '/home/memories',
        '/home/recent-albums',
        '/home/recent-artists',
      ];
      for (var i = 0; i < expected.length; i++) {
        await tester.tap(buttons.at(i));
        await tester.pumpAndSettle();
        expect(location(h), expected[i]);
        h.router.go('/home');
        await tester.pumpAndSettle();
      }
    });

    testWidgets('the recently added button follows the chip picked', (
      tester,
    ) async {
      final h = HomeHarness(now: now);
      await addTracks(h, 1);
      await open(tester, h, '/home');
      await tester.tap(find.widgetWithText(ChoiceChip, '30 days'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('See all').at(1));
      await tester.pumpAndSettle();
      expect(location(h), '/home/recently-added?window=30d');
    });
  });

  group('recently added page', () {
    testWidgets('loads the next page near the end, without a limit', (
      tester,
    ) async {
      final h = HomeHarness(now: now);
      await addTracks(h, 450);
      await open(tester, h, '/home/recently-added?window=all', height: 800);
      final pages = homeRecentlyAddedPagesProvider(HomeAddedWindow.all);
      expect(h.container.read(pages).rows, hasLength(200));

      final list = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );
      final seen = <int>[];
      for (var i = 0; i < 4 && !h.container.read(pages).done; i++) {
        final position = tester.state<ScrollableState>(list).position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        seen.add(h.container.read(pages).rows.length);
      }
      expect(seen, [400, 450]);
      expect(h.container.read(pages).done, isTrue);
    });

    testWidgets('reads again on a change and keeps the scroll position', (
      tester,
    ) async {
      final h = HomeHarness(now: now);
      await addTracks(h, 30);
      await open(tester, h, '/home/recently-added?window=all', height: 600);
      final list = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );
      tester.state<ScrollableState>(list).position.jumpTo(400);
      await tester.pumpAndSettle();

      await h.addTrack('/m/new.mp3', addedAt: now.millisecondsSinceEpoch + 5);
      await tester.pumpAndSettle();

      final pages = homeRecentlyAddedPagesProvider(HomeAddedWindow.all);
      expect(h.container.read(pages).rows, hasLength(31));
      expect(tester.state<ScrollableState>(list).position.pixels, 400);
    });

    testWidgets('a chip swaps the location and the list', (tester) async {
      final h = HomeHarness(now: now);
      await h.addTrack('/m/new.mp3', addedAt: daysAgo(0));
      await h.addTrack('/m/old.mp3', addedAt: daysAgo(10));
      await open(tester, h, '/home/recently-added?window=1d');
      expect(find.text('T /m/new.mp3'), findsOneWidget);
      expect(find.text('T /m/old.mp3'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();

      expect(location(h), '/home/recently-added?window=all');
      expect(find.text('T /m/new.mp3'), findsOneWidget);
      expect(find.text('T /m/old.mp3'), findsOneWidget);
      expect(
        h.container.read(homeAddedWindowChoiceProvider),
        HomeAddedWindow.all,
      );
    });

    testWidgets('an unknown window opens on the one in effect', (tester) async {
      final h = HomeHarness(now: now);
      await h.addTrack('/m/old.mp3', addedAt: daysAgo(10));
      await open(tester, h, '/home/recently-added?window=xyz');
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '30 days'),
      );
      expect(chip.selected, isTrue);
      expect(find.text('T /m/old.mp3'), findsOneWidget);
    });

    testWidgets('a period without songs says so', (tester) async {
      final h = HomeHarness(now: now);
      await h.addTrack('/m/old.mp3', addedAt: daysAgo(10));
      await open(tester, h, '/home/recently-added?window=1d');
      expect(find.text('No songs were added in this period'), findsOneWidget);
    });
  });

  group('other pages', () {
    testWidgets('memories with nothing says the sentence', (tester) async {
      final h = HomeHarness(now: now);
      await addTracks(h, 1);
      await open(tester, h, '/home/memories');
      expect(find.text('No music from this time last year'), findsOneWidget);
    });

    testWidgets('memories lists songs played this time last year', (
      tester,
    ) async {
      final h = HomeHarness(now: now);
      await addTracks(h, 2);
      await h.db.insertLibraryPlay(
        path: '/m/1.mp3',
        playedAt: DateTime(2025, 10, 23, 9).millisecondsSinceEpoch,
        listenedMs: 200000,
      );
      await open(tester, h, '/home/memories');
      expect(find.text('T /m/1.mp3'), findsOneWidget);
      expect(find.text('T /m/0.mp3'), findsNothing);
    });

    testWidgets('albums and artists with nothing say a sentence', (
      tester,
    ) async {
      final h = HomeHarness(now: now);
      await addTracks(h, 1);
      await open(tester, h, '/home/recent-albums');
      expect(find.text('No albums played yet'), findsOneWidget);
      h.router.go('/home/recent-artists');
      await tester.pumpAndSettle();
      expect(find.text('No artists played yet'), findsOneWidget);
    });

    testWidgets('played albums and artists fill a grid', (tester) async {
      final h = HomeHarness(now: now);
      await h.addTrack('/m/a.mp3', artist: 'Ann', album: 'First');
      await h.db.insertLibraryPlay(
        path: '/m/a.mp3',
        playedAt: now.millisecondsSinceEpoch - 1000,
        listenedMs: 200000,
      );
      await open(tester, h, '/home/recent-albums');
      expect(find.text('First'), findsOneWidget);
      h.router.go('/home/recent-artists');
      await tester.pumpAndSettle();
      expect(find.text('Ann'), findsOneWidget);
    });
  });
}
